#
# Tcl package index file
#

package ifneeded tls 1.7.16.0.2 [string map [list @ $dir] {

    switch -- $::tcl_platform(platform) {
        windows {
                switch -- $::tcl_platform(pointerSize) {
                    4 { set libfile dll/win/x32/tcltls.dll }
                    8 { set libfile dll/win/x64/tcltls.dll }
                    default { error "Unexpected pointer-size !!! "}
                }
        }                        
        unix {
            switch -- $::tcl_platform(os) {
            Linux {
                switch -- $::tcl_platform(pointerSize) {
                    4 { set libfile dll/linux/x32/tcltls-1.7.12.so }
                    8 { set libfile dll/linux/x64/tcltls.so }
                    default { error "Unexpected pointer-size !!! "}
                }                        
            }
            Darwin {
                set libfile dll/macosx/x64/tcltls.dylib
            }
            default { error "tls:: unsupported platform" }
            }
        }
        default { error "tls:: unsupported platform" }
    }
	load [file join {@} $libfile] Tls
    source [file join {@} tls.tcl]

	 # PATCH - I'm too lazy to rebuild binaries...
	 # Current binaries are version 1.7.16 (but linux-32 is 1.7.12);
	 # I want they be known as 1.7.16.0.2
	package forget tls
	package provide tls 1.7.16.0.2

}]

