#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# === Configuration ===
# If your kicad-cli is in a custom location, provide the full path here.
# For Mac users: CUSTOM_KICAD_PATH="/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli"
CUSTOM_KICAD_PATH="kicad-cli"

# Define a wrapper function to handle execution robustly
if command -v "$CUSTOM_KICAD_PATH" &> /dev/null; then
  run_kicad_cli() { "$CUSTOM_KICAD_PATH" "$@"; }
elif command -v flatpak &> /dev/null && flatpak list | grep -iq org.kicad.kicad; then
  echo "-> Standard 'kicad-cli' not found in PATH. Flatpak KiCad detected, using that..."
  run_kicad_cli() { flatpak run --command=kicad-cli org.kicad.KiCad "$@"; }
else
  echo "Error: 'kicad-cli' command not found."
  echo "Please ensure KiCad 7.0 (or newer) is installed."
  echo "If you installed KiCad via AppImage or a custom folder, edit CUSTOM_KICAD_PATH at the top of this script."
  exit 1
fi

# Check if a file was provided
if [ -z "$1" ]; then
  echo "Usage: ./make_gcode.sh <path_to_board.kicad_pcb>"
  exit 1
fi

KICAD_FILE="$1"
# Extract just the filename without the path and extension
BASENAME=$(basename "$KICAD_FILE" .kicad_pcb)

# Create a temporary directory in the CURRENT directory to avoid Flatpak /tmp sandbox issues
GERBER_DIR=$(mktemp -d "./tmp_gerbers.XXXXXX")

# Ensure the temporary directory is cleaned up when the script exits
trap 'rm -rf "$GERBER_DIR"' EXIT

echo "=== Starting PCB Automation for: $BASENAME ==="

echo "-> Generating embedded configuration files..."
cat << 'EOF' > "$GERBER_DIR/gcode.cfg"
# Machine settings
metric=true
metricoutput=true         # Forces the final G-code to be in Millimeters (G21) instead of Inches (G20)
nog64=true                # Prevents generating G64, which is unsupported by FluidNC/Grbl
zsafe=2.0                 # Safe Z height for traveling (above board)
zchange=10.0              # Z height for tool changes
nom6=true                 # Disable M6 tool change commands
zwork=-0.1                # Z-coordinate while engraving (isolation milling depth)
zero-start=1              # Set the starting point of the project at (0,0)

# Z-axis Depths (Assuming standard 1.6mm thick PCB)
zdrill=-1.7               # Depth for drilling holes (1.6mm board + 0.2mm overcut)
zcut=-1.7                 # Depth for cutting the board outline

# Speeds and Feeds (Conservative for 3018)
mill-feed=150             # Feed rate for XY milling (mm/min)
mill-vertfeed=80          # Plunge rate for Z-axis (mm/min)
mill-speed=10000          # Spindle RPM for milling
spinup-time=1             # Reduced to 1s since our preamble handles the main spin-up delay

# Milling Settings
isolation-width=0.1       # Width of the isolation cut
milling-overlap=20%       # Overlap between multiple isolation passes
mill-diameters=0.1        # Tip diameter of your V-bit (change to your actual bit size)
tsp-2opt=true             # FluidNC tweak: Optimizes travel paths to save time

# Drilling
drill-speed=10000         # Spindle RPM for drilling
drill-feed=100            # Plunge rate for drilling

# Outline Cutting Settings
cut-feed=100              # Feed rate for cutting the board outline
cut-speed=10000           # Spindle speed for outline
cut-infeed=0.3            # Maximum depth per pass (crucial for 3018 to not break the bit!)
cutter-diameter=1.0       # Diameter of the end mill used for cutting the board outline
cut-vertfeed=50           # Plunge rate for the outline cutter
bridges=1
bridgesnum=4
zbridges=0.8
EOF

cat << 'EOF' > "$GERBER_DIR/preamble.gcode"
(--- FluidNC Safety Setup ---)
G21 (Metric mode)
G90 (Absolute positioning)
G94 (Units per minute feed mode)
G17 (XY plane selection)
(--- Custom Soft Spindle Start ---)
(Gradually increases spindle speed to avoid power supply voltage drops/spikes)
M3 S2500  (Start at 25% power)
G4 P1     (Wait 1 second)
M3 S5000  (50% power)
G4 P1     (Wait 1 second)
M3 S7500  (75% power)
G4 P1     (Wait 1 second)
M3 S10000 (100% power)
G4 P2     (Wait 2 seconds to stabilize)
(--- End Soft Start ---)
M7 (Coolant On)
EOF

# 1. Export Gerbers using KiCad CLI (Requires KiCad 7.0 or newer)
# Added F.Mask and B.Mask to the layer exports
echo "-> Exporting Gerber layers (Front, Back, Masks, Edge Cuts)..."
run_kicad_cli pcb export gerbers \
  --layers "F.Cu,B.Cu,F.Mask,B.Mask,Edge.Cuts" \
  --output "$GERBER_DIR/" \
  "$KICAD_FILE"

# 2. Export Drill File
echo "-> Exporting Excellon Drill files..."
run_kicad_cli pcb export drill \
  --output "$GERBER_DIR/" \
  --format excellon \
  --drill-origin absolute \
  --excellon-zeros-format keep \
  "$KICAD_FILE"

# 3. Generate G-Code using pcb2gcode for Copper Isolation
# We use --output-dir so all the SVGs and G-codes are built in the temp folder safely.
echo "-> Running pcb2gcode for Copper Layers..."
pcb2gcode \
  --config="$GERBER_DIR/gcode.cfg" \
  --preamble="$GERBER_DIR/preamble.gcode" \
  --output-dir="$GERBER_DIR" \
  --front="$GERBER_DIR/${BASENAME}-F_Cu.gtl" \
  --back="$GERBER_DIR/${BASENAME}-B_Cu.gbl" \
  --outline="$GERBER_DIR/${BASENAME}-Edge_Cuts.gm1" \
  --drill="$GERBER_DIR/${BASENAME}.drl" \
  --front-output="${BASENAME}_front.gcode" \
  --back-output="${BASENAME}_back.gcode" \
  --outline-output="${BASENAME}_outline.gcode" \
  --drill-output="${BASENAME}_drill.gcode"

# 4. Generate G-Code using pcb2gcode for Solder Masks
# We use --invert-gerbers to mill INSIDE the pads to scrape the mask off.
# We override --isolation-width to fully pocket/fill the pad shapes.
# We override --zwork to -0.05 to make a very shallow pass so we don't gouge the copper.
echo "-> Running pcb2gcode for Solder Masks..."
pcb2gcode \
  --config="$GERBER_DIR/gcode.cfg" \
  --preamble="$GERBER_DIR/preamble.gcode" \
  --output-dir="$GERBER_DIR" \
  --front="$GERBER_DIR/${BASENAME}-F_Mask.gts" \
  --back="$GERBER_DIR/${BASENAME}-B_Mask.gbs" \
  --invert-gerbers=true \
  --isolation-width=10 \
  --zwork=-0.05 \
  --front-output="${BASENAME}_front_mask.gcode" \
  --back-output="${BASENAME}_back_mask.gcode" \
  --outline-output="discard_outline.gcode" \
  --drill-output="discard_drill.gcode"

# 5. Retrieve only the final G-code files
echo "-> Moving G-code files to working directory..."
mv "$GERBER_DIR"/${BASENAME}_*.gcode .

echo "=== Success! ==="
echo "G-code files generated in the current directory (SVGs discarded):"
ls -1 ${BASENAME}_*.gcode
