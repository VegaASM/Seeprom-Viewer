# Seeprom Viewer

by VegaASM

Credits to Team Twiizers (original seeprom_read code)

Seeprom Viewer is a Homebrew Channel Application that displays the contents of your Seeprom onto the screen. The display will be shown in a Hex-Editor like fashion. Press the Home/Start Button on your controller to exit back to HBC at any time. The app is made via Inline ASM. The part of the source (within /build/main.s) for reading from the SEEPROM was originally made by Team Twiizers in C. I rewrote/optimized it in full ASM.

Copy of the original C code plus the GPLv2 License are contained in the orgcodelicense.zip file.

For a regular binary download of the HBC app, go to the Releases tab/section. If you instead want to compile from source, keep reading.

How to Compile & Run:

Requirements: DevkitPPC on your computer, HBC on your Wii Console. The version of HBC must be 1.1.0 or 1.1.2. If using any other version of HBC, this app may not work.

Using devkit's PPC Assembler within binutils, compile the main.s to object code (named as main.o). View the compilation example below for exact details. Then simply run make on the makefile to compile the dol file. Rename the newly created dol file to boot.dol. Place boot.dol in the seeprom-viewer-hbc directory. Place that directly in the apps directory of your SD/USB device. Launch HBC, launch the app.

Compilation example (Linux):

1: cd /path/to/your/binutils

2: ./powerpc-eabi-as -mregnames -mbroadway /path/to/Seeprom-Viewer/build/main.s -o /path/to/Seeprom-Viewer/build/main.o

3: cd /path/to/Seeprom-Viewer

4: make

Change Log / History

v0.8 Dec 22, 2021 - HBC app now available for binary release download in the Releases tab/section of the GitHub repo. Added GCN controller support. Added some font colors to certain text. Properly allocated memory for contents that are being displayed. Added error checks for memalign and sprintf. Updated makefile with '-0s' tag. No more custom 'Hex to ASCII' subroutine for prepping all seeprom content for the printf. A sprintf loop is now used. Once again optimized seeprom source.

v0.7 Oct 15, 2019 - Optimized both seeprom and overall main.s source code.

v0.6 Oct 12, 2019 - Optimized overall main.s source code. 'Seeprom' changed to all caps on the icon.png.

v0.5 Oct 11, 2019 - Optimized seeprom source code, added extra details below title.

v0.4 Oct 10, 2019 - Optimized seeprom source code, added message notifying HBC return is occuring when Home Button is pressed.

v0.3 Oct 08, 2019 - Icon.png added, meta.xml updated w/ more info.

v0.2 Oct 07, 2019 - Optimized seeprom source code.

v0.1 Sep 30, 2019 - Displays Contents in a Hex Editor like grid. Title added at top. Meta.xml added.

v0.0 Sep 29, 2019 - Source able to compile and run on the Wii
