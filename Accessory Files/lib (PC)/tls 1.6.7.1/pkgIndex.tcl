package ifneeded tls 1.6.7.1 \
    "[list source [file join $dir tls.tcl]] ; \
     [list tls::initlib $dir tls1671.dll]"
