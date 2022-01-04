##
# QR Code generator for TCL
#
# Copyright (c) 2021 by Alexander Demenchuk <alexander.demenchuk@gmail.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
package provide qrcode 1.0

namespace eval ::qrcode {

    set errorCorrectionLevels { L M Q H }

    ##
    # Builds QR code bit matrix.
    #
    # @param text data to put into the QR Code
    # @param args optional pairs of additional arguments:
    #   -eclevel L|M|Q|H required error correction level
    #   -mask num   data masking pattern to use. This option is used for debugging.
    #               Do not use it as the mask pattern must be selected automatically.
    #   -forceEC num  Exact EC level to use. This option is used for debugging. Overrides -eclevel.
    # @return matrix (list of list) of bits (each bit is a number - 0 for light and 1 for dark)
    #
    proc make { text args } {
        variable errorCorrectionLevels

        if { [catch {dict get $args -eclevel} eclevel] } {
            set eclevel L
        }
        set minErrorCorrectionLevel [lsearch $errorCorrectionLevels $eclevel]
        if { $minErrorCorrectionLevel < 0 } {
            return -code error "invallid EC level"
        }
        if { [catch {dict get $args -mask} maskPattern] || [scan $maskPattern %d maskPattern] != 1 || $maskPattern < 0 || 7 < $maskPattern } {
            set maskPattern {}
        }

        lassign [selectQR $text $minErrorCorrectionLevel] mode version errorCorrectionLevel

        if { ![catch {dict get $args -forceEC} forcedEC] && [scan $forcedEC %d forcedEC] == 1 && 0 <= $forcedEC && $forcedEC <= 3 } {
            set minErrorCorrectionLevel $forcedEC
        }

        set data [encodeData $text $mode $version $errorCorrectionLevel]
        set data [makeMessage $data $version $errorCorrectionLevel]

        set bestPattern $maskPattern
        if { $bestPattern == {} } {
            set minPenalty 9223372036854775807
            for { set maskPattern 0 } { $maskPattern <= 7 } { incr maskPattern } {
                set maskPenalty [create $data $version $errorCorrectionLevel $maskPattern -score]
                if { $maskPenalty < $minPenalty } {
                    set minPenalty $maskPenalty
                    set bestPattern $maskPattern
                }
            }
        }
        return [create $data $version $errorCorrectionLevel $bestPattern]
    }

    # Max length table is indexed by mode, errorCorrectionLevel, version
    set maxLength {
        {
            {   41   77  127  187  255  322  370  461  552  652  772  883 1022 1101 1250 1408 1548 1725 1903 2061 2232 2409 2620 2812 3057 3283 3517 3669 3909 4158 4417 4686 4965 5253 5529 5836 6153 6479 6743 7089 }
            {   34   63  101  149  202  255  293  365  432  513  604  691  796  871  991 1082 1212 1346 1500 1600 1708 1872 2059 2188 2395 2544 2701 2857 3035 3289 3486 3693 3909 4134 4343 4588 4775 5039 5313 5596 }
            {   27   48   77  111  144  178  207  259  312  364  427  489  580  621  703  775  876  948 1063 1159 1224 1358 1468 1588 1718 1804 1933 2085 2181 2358 2473 2670 2805 2949 3081 3244 3417 3599 3791 3993 }
            {   17   34   58   82  106  139  154  202  235  288  331  374  427  468  530  602  674  746  813  919  969 1056 1108 1228 1286 1425 1501 1581 1677 1782 1897 2022 2157 2301 2361 2524 2625 2735 2927 3057 }
        } {
            {   25   47   77  114  154  195  224  279  335  395  468  535  619  667  758  854  938 1046 1153 1249 1352 1460 1588 1704 1853 1990 2132 2223 2369 2520 2677 2840 3009 3183 3351 3537 3729 3927 4087 4296 }
            {   20   38   61   90  122  154  178  221  262  311  366  419  483  528  600  656  734  816  909  970 1035 1134 1248 1326 1451 1542 1637 1732 1839 1994 2113 2238 2369 2506 2632 2780 2894 3054 3220 3391 }
            {   16   29   47   67   87  108  125  157  189  221  259  296  352  376  426  470  531  574  644  702  742  823  890  963 1041 1094 1172 1263 1322 1429 1499 1618 1700 1787 1867 1966 2071 2181 2298 2420 }
            {   10   20   35   50   64   84   93  122  143  174  200  227  259  283  321  365  408  452  493  557  587  640  672  744  779  864  910  958 1016 1080 1150 1226 1307 1394 1431 1530 1591 1658 1774 1852 }
        } {
            {   17   32   53   78  106  134  154  192  230  271  321  367  425  458  520  586  644  718  792  858  929 1003 1091 1171 1273 1367 1465 1528 1628 1732 1840 1952 2068 2188 2303 2431 2563 2699 2809 2953 }
            {   14   26   42   62   84  106  122  152  180  213  251  287  331  362  412  450  504  560  624  666  711  779  857  911  997 1059 1125 1190 1264 1370 1452 1538 1628 1722 1809 1911 1989 2099 2213 2331 }
            {   11   20   32   46   60   74   86  108  130  151  177  203  241  258  292  322  364  394  442  482  509  565  611  661  715  751  805  868  908  982 1030 1112 1168 1228 1283 1351 1423 1499 1579 1663 }
            {    7   14   24   34   44   58   64   84   98  119  137  155  177  194  220  250  280  310  338  382  403  439  461  511  535  593  625  658  698  742  790  842  898  958  983 1051 1093 1139 1219 1273 }
        }
    }

    ##
    # Given the text and the desired (minum) error correction level
    # returns a list with version, encoding-mode and the error correction level
    #
    # @param text data to put into the QR Code
    # @param minErrorCorrectionLevel desired EC level
    # @return list with 3 items - data encoding mode (0 = numeric, 1 = alphanumeric, 2 - byte), QR version (0..39)
    #   and final error correction level. The latter will be the same or higher than what was passed as desired.
    #
    proc selectQR { text minErrorCorrectionLevel } {
        variable maxLength
        set errorCorrectionLevel $minErrorCorrectionLevel
        set mode [getEncoding $text]
        set numChars [string length $text]
        set maxChars [lindex $maxLength $mode $errorCorrectionLevel]
        set version 0
        while { $version < 40 && $numChars > [lindex $maxChars $version] } {
            incr version
        }
        if { $version == 40 } {
            return -code error "the text is too long"
        }
        # Check if we can raise error correction level.
        # The available space will be just padded otherwise.
        set maxErrorCorrectionLevel 3
        while { $errorCorrectionLevel <= $maxErrorCorrectionLevel } {
            set nextErrorCorrectionLevel [expr { $errorCorrectionLevel + 1 }]
            set maxCharsNextErrorCorrectionLevel [lindex $maxLength $mode $nextErrorCorrectionLevel $version]
            if { $numChars > $maxCharsNextErrorCorrectionLevel } {
                break
            }
            set errorCorrectionLevel $nextErrorCorrectionLevel
        }
        return [list $mode $version $errorCorrectionLevel]
    }

    ##
    # Performs the data analysis and returns the encoding mode
    #
    # @param text data to put into the QR Code
    # @return data encoding mode (0 = numeric, 1 = alphanumeric, 2 - byte)
    #
    proc getEncoding { text } {
        if { [regexp {^[0-9]+$} $text] } {
            return 0
        }
        if { [regexp {^[0-9A-Z $%*+./:-]+$} $text] } {
            return 1
        }
        # Check that the text is encoded - all chars are in 0..255 range
        if { [regexp {^[\x00-\xff]+$} $text] } {
            return 2
        }
        return -code error "Input string contains Unicode character(s). Convert it to iso8859-1, if possible, or to utf-8."
    }

    ##
    # Creates QR code matrix.
    #
    # @param data encoded and interleaved data and error correction
    # @param version QR version (0..39)
    # @param errorCorrectionLevel EC level (0..3)
    # @param maskPattern data mask pattern (0..7)
    # @param args anything here indicates that function creates a QR matrix
    #             only to evaluate the penalty score of the specified mask pattern
    # @return list of lists of numbers (0 or 1) of matrix bits
    #         or data mask pattern penalty score
    #
    proc create { data version errorCorrectionLevel maskPattern args } {
        set moduleCount [expr { $version * 4 + 21 }]
        set modules [lrepeat $moduleCount [lrepeat $moduleCount {}]]

        putFinderPattern modules 0 0
        putFinderPattern modules $moduleCount-7 0
        putFinderPattern modules 0 $moduleCount-7
        putFinderSeparators modules
        putAlignmentPatterns modules $version
        putTimingPatters modules

        if { [llength $args] > 0 } {
            reserveFormatAreas modules
            if { $version >= 6 } { # note that internal version is 1 less than the QR version
                reserveVersionAreas modules
            }
        } else {
            putFormatData modules $errorCorrectionLevel $maskPattern
            if { $version >= 6 } {
                putVersionData modules $version
            }
        }
        # Set Dark Module
        lset modules [expr { $moduleCount - 8 }] 8 1

        switch $maskPattern {
            0 { set bitMaskFun { { row col } { expr ($row + $col) % 2 == 0 } } }
            1 { set bitMaskFun { { row col } { expr $row % 2 == 0 } } }
            2 { set bitMaskFun { { row col } { expr $col % 3 == 0 } } }
            3 { set bitMaskFun { { row col } { expr ($row + $col) % 3 == 0 } } }
            4 { set bitMaskFun { { row col } { expr ($row / 2 + $col / 3) % 2 == 0 } } }
            5 { set bitMaskFun { { row col } { expr (($row * $col) % 2 + ($row * $col) % 3) == 0 } } }
            6 { set bitMaskFun { { row col } { expr (($row * $col) % 2 + ($row * $col) % 3) % 2 == 0 } } }
            7 { set bitMaskFun { { row col } { expr (($row + $col) % 2 + ($row * $col) % 3) % 2 == 0 } } }
        }
        putData modules $data $bitMaskFun

        if { [llength $args] > 0 } {
            return [getPenaltyScore modules]
        } else {
            return $modules
        }
    }

    ##
    # Dumps current matrix to standard output.
    #
    # @param modulesVar reference to a matrix of QR modules
    #
    proc dump { modulesVar } {
        upvar $modulesVar modules
        set size [llength $modules]
        for { set row 0 } { $row < $size } { incr row } {
            puts -nonewline [format {%2d: } $row]
            for { set col 0 } { $col < $size } { incr col } {
                set val [lindex $modules $row $col]
                switch $val {
                    0  { puts -nonewline "." }
                    1  { puts -nonewline "x" }
                    {} { puts -nonewline "_" }
                    default { return -code error "module is '$val' at $row,$col" }
                }
            }
            puts ""
        }
    }

    ##
    # Places data bits into QR matrix.
    #
    # @param modulesVar reference to a matrix of QR modules
    # @param msg list of bytes
    # @param bitMaskFun data masking (lambda) function
    #
    proc putData { modulesVar msg bitMaskFun } {
        upvar $modulesVar modules

        set stream [list $msg 0 [lindex $msg 0] 0x80]

        set maxRowCol [expr { [llength $modules] - 1 }]
        set col $maxRowCol

        while { $col >= 0 } {
            # upward
            set row $maxRowCol
            while { $row >= 0 } {
                putNextBit modules $row $col $bitMaskFun stream
                putNextBit modules $row [expr { $col - 1 }] $bitMaskFun stream
                incr row -1
            }
            # downward
            incr col -2
            if { $col == 6 } {
                # skip vertical timing pattern column
                incr col -1
            }
            set row 0
            while { $row <= $maxRowCol } {
                putNextBit modules $row $col $bitMaskFun stream
                putNextBit modules $row [expr { $col - 1 }] $bitMaskFun stream
                incr row 1
            }
            incr col -2
        }
        set lastByteIdx [lindex $stream 1]
        if { [llength $msg] - 1 != $lastByteIdx } {
            return -code error "stopped at $lastByteIdx / [llength $msg]"
        }
    }

    ##
    # Tries to put next bit from the stream into the module.
    #
    # @param modulesVar reference to a matrix of QR modules
    # @param row module row
    # @param row module column
    # @param bitMaskFun lambda function with QR mask formular
    # @param streamVar reference to the stream {bytes byteIdx byte mask}
    #
    proc putNextBit { modulesVar row col bitMaskFun streamVar } {
        upvar $modulesVar modules
        upvar $streamVar stream
        lassign $stream bytes byteIdx byte mask

        if { [lindex $modules $row $col] == {} } {
            set inv [apply $bitMaskFun $row $col]
            set bit [expr { ($byte & $mask) != 0 ^ $inv }]
            lset modules $row $col $bit
            set mask [expr { $mask >> 1 }]
            if { $mask != 0 } {
                lset stream end $mask
            } else {
                lset stream   1 [incr byteIdx]
                lset stream   2 [lindex $bytes $byteIdx]
                lset stream end 0x80
            }
        }
    }

    ##
    # Calculates penalty score for the current QR code.
    #
    # @param modulesVar reference to a matrix of QR modules
    # @return penalty score
    #
    proc getPenaltyScore { modulesVar } {
        upvar $modulesVar modules
        set moduleCount [llength $modules]

        set score 0

        # 1. Five consecutive modules of the same color
        for { set row 0 } { $row < $moduleCount } { incr row } {
            set color {}
            set count 0
            for { set col 0 } { $col < $moduleCount } { incr col } {
                set val [lindex $modules $row $col]
                if { $val == $color } {
                    incr count
                } else {
                    if { $count >= 5 } {
                        incr score [expr { $count - 2 }]
                    }
                    set color $val
                    set count 1
                }
            }
            if { $count >= 5 } {
                incr score [expr { $count - 2 }]
            }
        }
        for { set col 0 } { $col < $moduleCount } { incr col } {
            set color {}
            set count 0
            for { set row 0 } { $row < $moduleCount } { incr row } {
                set val [lindex $modules $row $col]
                if { $val == $color } {
                    incr count
                } else {
                    if { $count >= 5 } {
                        incr score [expr { $count - 2 }]
                    }
                    set color $val
                    set count 1
                }
            }
            if { $count >= 5 } {
                incr score [expr { $count - 2 }]
            }
        }

        # 2. Areas of the same color that are at least 2x2 modules or larger.
        set end [expr { $moduleCount - 1 }]
        for { set row 0 } { $row < $end } { incr row } {
            for { set col 0 } { $col < $end } { incr col } {
                set tl [lindex $modules $row $col]
                set tr [lindex $modules $row $col+1]
                if { $tr == $tl } {
                    set bl [lindex $modules $row+1 $col]
                    if { $bl == $tl } {
                        set br [lindex $modules $row+1 $col+1]
                        if { $br == $tl } {
                            incr score 3
                        }
                    }
                }
            }
        }

        # 3. Finder-like patterns - Patterns of dark-light-dark-dark-dark-light-dark
        #    that have four light modules on either side.
        #    These have to take into account the quiet zone around the matrix.
        set last [expr { $moduleCount - 7 }]
        for { set row 0 } { $row < $moduleCount } { incr row } {
            for { set col 0 } { $col <= $last } { incr col } {
                if {
                    [lindex $modules $row $col]   == 1 &&
                    [lindex $modules $row $col+1] == 0 &&
                    [lindex $modules $row $col+2] == 1 &&
                    [lindex $modules $row $col+3] == 1 &&
                    [lindex $modules $row $col+4] == 1 &&
                    [lindex $modules $row $col+5] == 0 &&
                    [lindex $modules $row $col+6] == 1
                } {
                    set found [expr { $col == 0 || $col == $last }]
                    if { !$found } {
                        set left [expr { $col < 4 ? 0 : $col - 4 }]
                        while { $left < $col && [lindex $modules $row $left] != 0 } { incr left }
                        set found [expr { $left == $col }]
                    }
                    if { !$found } {
                        set right [expr { $col + 6 + min($last - $col, 4) } ]
                        while { $right < $moduleCount && [lindex $modules $row $right] != 0 } { incr right }
                        set found [expr { $right == $moduleCount }]
                    }
                    if { $found } {
                        incr score 40
                    }
                }
            }
        }
        for { set col 0 } { $col < $moduleCount } { incr col } {
            for { set row 0 } { $row <= $last } { incr row } {
                if {
                    [lindex $modules $row   $col] == 1 &&
                    [lindex $modules $row+1 $col] == 0 &&
                    [lindex $modules $row+2 $col] == 1 &&
                    [lindex $modules $row+3 $col] == 1 &&
                    [lindex $modules $row+4 $col] == 1 &&
                    [lindex $modules $row+5 $col] == 0 &&
                    [lindex $modules $row+6 $col] == 1
                } {
                    set found [expr { $col == 0 || $col == $last }]
                    if { !$found } {
                        set top [expr { $row < 4 ? 0 : $row - 4 }]
                        while { $top < $row && [lindex $modules $top $col] != 0 } { incr top }
                        set found [expr { $top == $row }]
                    }
                    if { !$found } {
                        set bottom [expr { $row + 6 + min($last - $row, 4) } ]
                        while { $bottom < $moduleCount && [lindex $modules $bottom $col] != 0 } { incr bottom }
                        set found [expr { $bottom == $moduleCount }]
                    }
                    if { $found } {
                        incr score 40
                    }
                }
            }
        }

        # 4. Ratio of light modules to dark modules
        set numDark 0
        for { set row 0 } { $row < $moduleCount } { incr row } {
            for { set col 0 } { $col < $moduleCount } { incr col } {
                incr numDark [expr { [lindex $modules $row $col] == 1 }]
            }
        }
        incr score [expr { abs( $numDark * 100 / $moduleCount / $moduleCount - 50 ) / 5 * 10 }]

        return $score
    }

    ##
    # Copies specified pattern into QR matrix.
    #
    # @param modulesVar reference to a matrix of QR modules
    # @param row matrix row where the top left corner of the pattern will be placed
    # @param col matrix column of the top left corner
    # @param patternName name of the pattern (finderPattern or alignmentPattern)
    #
    proc putPattern { modulesVar row col patternName } {
        upvar $modulesVar modules
        upvar [namespace current]::$patternName pattern

        set row     [expr $row]
        set leftCol [expr $col]

        foreach patternRow $pattern {
            set col $leftCol
            foreach val $patternRow {
                lset modules $row $col $val
                incr col
            }
            incr row
        }
    }

    set finderPattern {
        { 1 1 1 1 1 1 1 }
        { 1 0 0 0 0 0 1 }
        { 1 0 1 1 1 0 1 }
        { 1 0 1 1 1 0 1 }
        { 1 0 1 1 1 0 1 }
        { 1 0 0 0 0 0 1 }
        { 1 1 1 1 1 1 1 }
    }

    ##
    # Creates finder pattern at the specified location
    #
    # @param modulesVar reference to a matrix of QR modules
    # @param row matrix row where the top left corner of the pattern will be placed
    # @param col matrix column of the top left corner
    #
    proc putFinderPattern { modulesVar row col } {
        upvar $modulesVar modules

        putPattern modules $row $col finderPattern
    }

    set alignmentPattern {
        { 1 1 1 1 1 }
        { 1 0 0 0 1 }
        { 1 0 1 0 1 }
        { 1 0 0 0 1 }
        { 1 1 1 1 1 }
    }

    ##
    # Creates alignment pattern at the specified location if possible.
    # Alignment pattern will not be created if its location is already occupied
    # (by timing or finder patterns).
    #
    # @param modulesVar reference to a matrix of QR modules
    # @param row matrix row where the center point of the alighnment pattern will be placed
    # @param col matrix column of the center point
    #
    proc putAlignmentPattern { modulesVar row col } {
        upvar $modulesVar modules

        if { [lindex $modules $row $col] == {} } {
            putPattern modules $row-2 $col-2 alignmentPattern
        }
    }

    ##
    # Table of alignment locations.
    #
    # Table is indexed by version. Foreach version all possible combinations
    # of the returned numbers need to be created to derive allignment locations.
    #
    set alignmentPatternLocations {
        {}
        {6 18}
        {6 22}
        {6 26}
        {6 30}
        {6 34}
        {6 22 38}
        {6 24 42}
        {6 26 46}
        {6 28 50}
        {6 30 54}
        {6 32 58}
        {6 34 62}
        {6 26 46 66}
        {6 26 48 70}
        {6 26 50 74}
        {6 30 54 78}
        {6 30 56 82}
        {6 30 58 86}
        {6 34 62 90}
        {6 28 50 72 94}
        {6 26 50 74 98}
        {6 30 54 78 102}
        {6 28 54 80 106}
        {6 32 58 84 110}
        {6 30 58 86 114}
        {6 34 62 90 118}
        {6 26 50 74 98 122}
        {6 30 54 78 102 126}
        {6 26 52 78 104 130}
        {6 30 56 82 108 134}
        {6 34 60 86 112 138}
        {6 30 58 86 114 142}
        {6 34 62 90 118 146}
        {6 30 54 78 102 126 150}
        {6 24 50 76 102 128 154}
        {6 28 54 80 106 132 158}
        {6 32 58 84 110 136 162}
        {6 26 54 82 110 138 166}
        {6 30 58 86 114 142 170}
    }

    ##
    # Creates all alignment patterns in the QR matrix.
    #
    # @param modulesVar reference to a matrix of QR modules
    # @param version QR version
    #
    proc putAlignmentPatterns { modulesVar version } {
        upvar $modulesVar modules
        variable alignmentPatternLocations

        set locations [lindex $alignmentPatternLocations $version]
        foreach row $locations {
            foreach col $locations {
                putAlignmentPattern modules $row $col
            }
        }
    }

    ##
    # Creates separators around finder patterns.
    #
    # @param modulesVar reference to a matrix of QR modules
    #
    proc putFinderSeparators { modulesVar } {
        upvar $modulesVar modules

        set moduleCount [llength $modules]
        set end [expr { $moduleCount - 8 }]

        for { set i 0 } { $i < 8 } { incr i } {
            lset modules 7 $i 0
            lset modules $end $i 0
            lset modules 7 $end+$i 0
            lset modules $i 7 0
            lset modules $i $end 0
            lset modules $end+$i 7 0
        }
    }

    ##
    # Creates timing patterns in the QR matrix.
    #
    # @param modulesVar reference to a matrix of QR modules
    #
    proc putTimingPatters { modulesVar } {
        upvar $modulesVar modules

        set moduleCount [llength $modules]
        set end [expr { $moduleCount - 8 }]

        set row 6
        for { set col 8 } { $col < $end } { incr col } {
            if { [lindex $modules $row $col] == {} } {
                lset modules $row $col [expr { $col % 2 ^ 1 }]
            }
        }

        set col 6
        for { set row 8 } { $row < $end } { incr row } {
            if { [lindex $modules $row $col] == {} } {
                lset modules $row $col [expr { $row % 2 ^ 1 }]
            }
        }
    }

    ##
    # Format table.
    #
    # Table is indexed by errorCorrectionLevel and mask pattern.
    #
    set formatTable {
        { 30660 29427 32170 30877 26159 25368 27713 26998 }
        { 21522 20773 24188 23371 17913 16590 20375 19104 }
        { 13663 12392 16177 14854  9396  8579 11994 11245 }
        {  5769  5054  7399  6608  1890   597  3340  2107 }
    }

    ##
    # Outputs QR format string (error correction and mask pattern).
    #
    # @param modulesVar reference to a matrix of QR modules
    # @param errorCorrectionLevel EC level (0..3)
    # @param maskPattern data mask pattern (0..7)
    #
    proc putFormatData { modulesVar errorCorrectionLevel maskPattern } {
        upvar $modulesVar modules
        variable formatTable

        set moduleCount [llength $modules]

        set formatData [lindex $formatTable $errorCorrectionLevel $maskPattern]

        set last [expr { $moduleCount - 1 }]
        for { set mod 0 } { $mod <= 5 } { incr mod } {
            set val [expr { ($formatData & (1 << (14 - $mod))) != 0 }]
            lset modules 8 $mod $val
            lset modules $last-$mod 8 $val
        }

        set mod 6
        set val [expr { ($formatData & (1 << (14 - $mod))) != 0 }]
        lset modules 8 7 $val
        lset modules $last-$mod 8 $val

        set mod 7
        set offset [expr { $last - 7 }]
        set val [expr { ($formatData & (1 << (14 - $mod))) != 0 }]
        lset modules 8 8 $val
        lset modules 8 $offset $val

        set mod 8
        set val [expr { ($formatData & (1 << (14 - $mod))) != 0 }]
        lset modules 7 8 $val
        lset modules 8 [incr offset] $val

        for { set mod 9 } { $mod <= 14 } { incr mod } {
            set val [expr { ($formatData & (1 << (14 - $mod))) != 0 }]
            lset modules 14-$mod 8 $val
            lset modules 8 [incr offset] $val
        }
    }

    ##
    # Reserves (paints with white) modules used for format string data.
    #
    # @param modulesVar reference to a matrix of QR modules
    #
    proc reserveFormatAreas { modulesVar } {
        upvar $modulesVar modules

        set moduleCount [llength $modules]
        set last [expr { $moduleCount - 1 }]

        for { set mod 0 } { $mod <= 5 } { incr mod } {
            lset modules 8 $mod 0
            lset modules $last-$mod 8 0
        }

        set mod 6
        lset modules 8 7 0
        lset modules $last-$mod 8 0

        set mod 7
        set offset [expr { $last - 7 }]
        lset modules 8 8 0
        lset modules 8 $offset 0

        set mod 8
        lset modules 7 8 0
        lset modules 8 [incr offset] 0

        for { set mod 9 } { $mod <= 14 } { incr mod } {
            lset modules 14-$mod 8 0
            lset modules 8 [incr offset] 0
        }
    }

    set versionInfo {
                                                   31892  34236  39577  42195
         48118  51042  55367  58893  63784  68472  70749  76311  79154  84390
         87683  92361  96236 102084 102881 110507 110734 117786 119615 126325
        127568 133589 136944 141498 145311 150283 152622 158308 161089 167017
    }

    ##
    # Outputs version string.
    #
    # @param modulesVar reference to a matrix of QR modules
    # @param version QR version (0..39)
    #
    proc putVersionData { modulesVar version } {
        upvar $modulesVar modules
        variable versionInfo

        set moduleCount [llength $modules]

        set versionString [lindex $versionInfo $version-6]

        # Bottom-left origin. Top-right is the mirror of that.
        set origRow [expr { $moduleCount - 11 }]
        set origCol 0
        set bit 0
        while { $bit < 18 } {
            set val [expr { ($versionString & ( 1 << $bit )) != 0 }]
            set row [expr { $origRow + $bit % 3 }]
            set col [expr { $origCol + $bit / 3 }]
            # set bottom left module
            lset modules $row $col $val
            # then mirror into top-right one
            lset modules $col $row $val
            incr bit
        }
    }

    ##
    # Reserves (paints with white) modules used for version data.
    #
    # @param modulesVar reference to a matrix of QR modules
    #
    proc reserveVersionAreas { modulesVar } {
        upvar $modulesVar modules

        set moduleCount [llength $modules]
        set end [expr $moduleCount - 8]
        for { set row [expr $moduleCount - 11] } { $row < $end } { incr row } {
            for { set col 0 } { $col < 6 } { incr col } {
                # set bottom left module
                lset modules $row $col 0
                # then mirror into top-right one
                lset modules $col $row 0
            }
        }
    }

    ##
    # Reed-Solomon block table.
    #
    # Table is indexed by errorCorrectionLevel, version. Each row (for EC, version)
    # contains:
    #  - Total Number of Data Codewords for this EC Level and Version
    #  - Number of EC Codewords Per Block
    #  - Number of Blocks in Group 1
    #  - Number of Data Codewords in Each of Group 1's Blocks
    #  - Number of Blocks in Group 2
    #  - Number of Data Codewords in Each of Group 2's Blocks
    #
    set rsBlocks {
        {
            {   19   7   1   19   0    0 }
            {   34  10   1   34   0    0 }
            {   55  15   1   55   0    0 }
            {   80  20   1   80   0    0 }
            {  108  26   1  108   0    0 }
            {  136  18   2   68   0    0 }
            {  156  20   2   78   0    0 }
            {  194  24   2   97   0    0 }
            {  232  30   2  116   0    0 }
            {  274  18   2   68   2   69 }
            {  324  20   4   81   0    0 }
            {  370  24   2   92   2   93 }
            {  428  26   4  107   0    0 }
            {  461  30   3  115   1  116 }
            {  523  22   5   87   1   88 }
            {  589  24   5   98   1   99 }
            {  647  28   1  107   5  108 }
            {  721  30   5  120   1  121 }
            {  795  28   3  113   4  114 }
            {  861  28   3  107   5  108 }
            {  932  28   4  116   4  117 }
            { 1006  28   2  111   7  112 }
            { 1094  30   4  121   5  122 }
            { 1174  30   6  117   4  118 }
            { 1276  26   8  106   4  107 }
            { 1370  28  10  114   2  115 }
            { 1468  30   8  122   4  123 }
            { 1531  30   3  117  10  118 }
            { 1631  30   7  116   7  117 }
            { 1735  30   5  115  10  116 }
            { 1843  30  13  115   3  116 }
            { 1955  30  17  115   0    0 }
            { 2071  30  17  115   1  116 }
            { 2191  30  13  115   6  116 }
            { 2306  30  12  121   7  122 }
            { 2434  30   6  121  14  122 }
            { 2566  30  17  122   4  123 }
            { 2702  30   4  122  18  123 }
            { 2812  30  20  117   4  118 }
            { 2956  30  19  118   6  119 }
        } {
            {   16  10   1   16   0    0 }
            {   28  16   1   28   0    0 }
            {   44  26   1   44   0    0 }
            {   64  18   2   32   0    0 }
            {   86  24   2   43   0    0 }
            {  108  16   4   27   0    0 }
            {  124  18   4   31   0    0 }
            {  154  22   2   38   2   39 }
            {  182  22   3   36   2   37 }
            {  216  26   4   43   1   44 }
            {  254  30   1   50   4   51 }
            {  290  22   6   36   2   37 }
            {  334  22   8   37   1   38 }
            {  365  24   4   40   5   41 }
            {  415  24   5   41   5   42 }
            {  453  28   7   45   3   46 }
            {  507  28  10   46   1   47 }
            {  563  26   9   43   4   44 }
            {  627  26   3   44  11   45 }
            {  669  26   3   41  13   42 }
            {  714  26  17   42   0    0 }
            {  782  28  17   46   0    0 }
            {  860  28   4   47  14   48 }
            {  914  28   6   45  14   46 }
            { 1000  28   8   47  13   48 }
            { 1062  28  19   46   4   47 }
            { 1128  28  22   45   3   46 }
            { 1193  28   3   45  23   46 }
            { 1267  28  21   45   7   46 }
            { 1373  28  19   47  10   48 }
            { 1455  28   2   46  29   47 }
            { 1541  28  10   46  23   47 }
            { 1631  28  14   46  21   47 }
            { 1725  28  14   46  23   47 }
            { 1812  28  12   47  26   48 }
            { 1914  28   6   47  34   48 }
            { 1992  28  29   46  14   47 }
            { 2102  28  13   46  32   47 }
            { 2216  28  40   47   7   48 }
            { 2334  28  18   47  31   48 }
        } {
            {   13  13   1   13   0    0 }
            {   22  22   1   22   0    0 }
            {   34  18   2   17   0    0 }
            {   48  26   2   24   0    0 }
            {   62  18   2   15   2   16 }
            {   76  24   4   19   0    0 }
            {   88  18   2   14   4   15 }
            {  110  22   4   18   2   19 }
            {  132  20   4   16   4   17 }
            {  154  24   6   19   2   20 }
            {  180  28   4   22   4   23 }
            {  206  26   4   20   6   21 }
            {  244  24   8   20   4   21 }
            {  261  20  11   16   5   17 }
            {  295  30   5   24   7   25 }
            {  325  24  15   19   2   20 }
            {  367  28   1   22  15   23 }
            {  397  28  17   22   1   23 }
            {  445  26  17   21   4   22 }
            {  485  30  15   24   5   25 }
            {  512  28  17   22   6   23 }
            {  568  30   7   24  16   25 }
            {  614  30  11   24  14   25 }
            {  664  30  11   24  16   25 }
            {  718  30   7   24  22   25 }
            {  754  28  28   22   6   23 }
            {  808  30   8   23  26   24 }
            {  871  30   4   24  31   25 }
            {  911  30   1   23  37   24 }
            {  985  30  15   24  25   25 }
            { 1033  30  42   24   1   25 }
            { 1115  30  10   24  35   25 }
            { 1171  30  29   24  19   25 }
            { 1231  30  44   24   7   25 }
            { 1286  30  39   24  14   25 }
            { 1354  30  46   24  10   25 }
            { 1426  30  49   24  10   25 }
            { 1502  30  48   24  14   25 }
            { 1582  30  43   24  22   25 }
            { 1666  30  34   24  34   25 }
        } {
            {    9  17   1    9   0    0 }
            {   16  28   1   16   0    0 }
            {   26  22   2   13   0    0 }
            {   36  16   4    9   0    0 }
            {   46  22   2   11   2   12 }
            {   60  28   4   15   0    0 }
            {   66  26   4   13   1   14 }
            {   86  26   4   14   2   15 }
            {  100  24   4   12   4   13 }
            {  122  28   6   15   2   16 }
            {  140  24   3   12   8   13 }
            {  158  28   7   14   4   15 }
            {  180  22  12   11   4   12 }
            {  197  24  11   12   5   13 }
            {  223  24  11   12   7   13 }
            {  253  30   3   15  13   16 }
            {  283  28   2   14  17   15 }
            {  313  28   2   14  19   15 }
            {  341  26   9   13  16   14 }
            {  385  28  15   15  10   16 }
            {  406  30  19   16   6   17 }
            {  442  24  34   13   0    0 }
            {  464  30  16   15  14   16 }
            {  514  30  30   16   2   17 }
            {  538  30  22   15  13   16 }
            {  596  30  33   16   4   17 }
            {  628  30  12   15  28   16 }
            {  661  30  11   15  31   16 }
            {  701  30  19   15  26   16 }
            {  745  30  23   15  25   16 }
            {  793  30  23   15  28   16 }
            {  845  30  19   15  35   16 }
            {  901  30  11   15  46   16 }
            {  961  30  59   16   1   17 }
            {  986  30  22   15  41   16 }
            { 1054  30   2   15  64   16 }
            { 1096  30  24   15  46   16 }
            { 1142  30  42   15  32   16 }
            { 1222  30  10   15  67   16 }
            { 1276  30  20   15  61   16 }
        }
    }

    ##
    # Encodes the data using previously selected version, encoding mode and error correction.
    #
    # @param text data to encode
    # @param mode encoding mode (0 = numeric, 1 = alphanumeric, 2 = byte)
    # @param version QR code version
    # @param errorCorrectionLevel EC level (0 = L, 1 = M, 2 = Q, 3 = H)
    # @return list of bytes
    #
    proc encodeData { text mode version errorCorrectionLevel } {
        variable rsBlocks

        set buf [list {} 0 0] ;# { byte-buffer bit-accumulator num-bits-in-accumulator }
        appendBits buf 4 [expr { 1 << $mode }] ;# the shift works for 3 modes that are currently supported
        appendBits buf [getCharacterCountFieldWidth $version $mode] [string length $text]

        switch $mode {
            0 { encodeNumericData      buf $text }
            1 { encodeAlphaNumericData buf $text }
            2 { encodeByteData         buf $text }
        }
        set totalDataLen [lindex $rsBlocks $errorCorrectionLevel $version 0]

        terminateAndPad buf $totalDataLen

        return [toBytes [lindex $buf 0]]
    }

    ##
    # Encodes the numeric data.
    #
    # @param bufVar buffer "object" reference
    # @param text data to encode
    # @return string where each character represents en encoded byte
    #
    proc encodeNumericData { bufVar text } {
        upvar $bufVar buf

        set textLen [string length $text]
        set endOf3digitGroups [expr { $textLen / 3 * 3 }]
        for { set offset 0 } { $offset < $endOf3digitGroups } { incr offset 3 } {
            set grp [string range $text $offset $offset+2]
            set val [scan $grp %d]
            appendBits buf 10 $val
        }
        set grp [string range $text $endOf3digitGroups end]
        set val [scan $grp %d]
        switch [string length $grp] {
            1 {
                appendBits buf 4 $val
            }
            2 {
                appendBits buf 7 $val
            }
        }
    }

    ##
    # Encodes the alphanumeric data.
    #
    # @param bufVar buffer "object" reference
    # @param text data to encode
    # @return string where each character represents en encoded byte
    #
    proc encodeAlphaNumericData { bufVar text } {
        upvar $bufVar buf

        set textLen [string length $text]
        set endOfPairs [expr { $textLen & ~1 }]
        for { set offset 0 } { $offset < $endOfPairs } { incr offset 2 } {
            set c1 [getAlphaNumericCode [string index $text $offset]]
            set c2 [getAlphaNumericCode [string index $text $offset+1]]
            set val [expr { $c1 * 45 + $c2 }]
            appendBits buf 11 $val
        }
        set tail [string range $text $endOfPairs end]
        if { [string length $tail] > 0 } {
            set val [getAlphaNumericCode $tail]
            appendBits buf 6 $val
        }
    }

    set alphanumericSymbols { $%*+-./:}

    ##
    # Converts alphanumeric character into the corresponding code
    #
    # @param c character to encode
    # @return character code in alphanumeric encoding
    #
    proc getAlphaNumericCode { c } {
        variable alphanumericSymbols

        if { "0" <= $c && $c <= "9" } {
            return [expr { [scan $c %c] - 48 }]
        }
        if { "A" <= $c && $c <= "Z" } {
            return [expr { [scan $c %c] - 55 }]
        }
        return [expr { 36 + [string first $c $alphanumericSymbols] }]
    }

    ##
    # Encodes the byte data (copies bytes into the output buffer)
    #
    # @param bufVar buffer "object" reference
    # @param text data to encode
    # @return string where each character represents en encoded byte
    #
    proc encodeByteData { bufVar text } {
        upvar $bufVar buf
        set textLen [string length $text]
        for { set i 0 } { $i < $textLen } { incr i } {
            appendBits buf 8 [scan [string index $text $i] %c]
        }
    }

    ##
    # Appends bits to the buffer.
    #
    # @param bufVar buffer "object" reference
    # @param numBits the number of bits to consume from the value
    # @param value the source of bits. The least significant bits are used.
    #
    proc appendBits { bufVar numBits value } {
        upvar $bufVar buf
        lassign $buf byteBuf acc accBitCount

        set acc [expr { $acc << $numBits | $value }]
        incr accBitCount $numBits
        while { $accBitCount >= 8 } {
            incr accBitCount -8
            set msb [expr { $acc >> $accBitCount & 0xff }]
            append byteBuf [format %c $msb]
            set acc [expr { $acc & (( 1 << $accBitCount ) - 1) }]
        }
        lset buf 0 $byteBuf
        lset buf 1 $acc
        lset buf 2 $accBitCount
    }

    ##
    # Adds terminating 0 bits and pad bytes if necessary
    #
    # @param bufVar buffer "object" reference
    # @param length the expected length of the buffer after it is padded
    #
    proc terminateAndPad { bufVar length } {
        upvar $bufVar buf
        lassign $buf byteBuf acc accBitCount

        if { $accBitCount >= 8 } {
            return -code error "too many bits in the byte-buffer accumulator"
        }

        if { $accBitCount > 0 } {
            set termBitCount [expr { 8 - $accBitCount }]
            set acc [expr { $acc << $termBitCount }]
            append byteBuf [format %c $acc]
        } else {
            set termBitCount 0
        }

        if { $termBitCount < 4 && [string length $byteBuf] < $length } {
            # Add remaining terminating bits, if any, and padd the (last) byte where they
            # were added with 0s. Effectively, append one more byte where all 8 bits are 0s.
            append byteBuf [format %c 0]
        }

        set numPads [expr { $length - [string length $byteBuf] }]
        while { $numPads >= 2 } {
            append byteBuf [format %c%c 0xec 0x11]
            incr numPads -2
        }
        if { $numPads > 0 } {
            append byteBuf [format %c 0xec]
        }
        lset buf 0 $byteBuf
    }

    ##
    # Converts buffered characters into a byte list.
    #
    # @param str string where each character is a byte
    # @return list of numbers where each number is a byte (0..255)
    #
    proc toBytes { str } {
        set lst [list]
        set len [string length $str]
        for { set i 0 } { $i < $len } { incr i } {
            set val [scan [string index $str $i] %c]
            if { $val > 255 } {
                return -code error "Unicode value encountered in the encoded data"
            }
            lappend lst $val
        }
        return $lst
    }

    ##
    # Returns the width of the message length bit-field,
    #
    # @param version QR code version (0..39)
    # @param mode data encoding mode (0..2)
    # @return width of the character count field in bits
    #
    proc getCharacterCountFieldWidth { version mode } {
        if { $version < 9 } {
            set modeWidth { 10  9  8 }
        } elseif { $version < 26 } {
            set modeWidth { 12 11 16 }
        } else {
            set modeWidth { 14 13 16 }
        }
        return [lindex $modeWidth $mode]
    }

    set generatorPolynomials [dict create \
         7 { 0 87 229 146 149 238 102 21 } \
        10 { 0 251 67 46 61 118 70 64 94 32 45 } \
        13 { 0 74 152 176 100 86 100 106 104 130 218 206 140 78 } \
        15 { 0 8 183 61 91 202 37 51 58 58 237 140 124 5 99 105 } \
        16 { 0 120 104 107 109 102 161 76 3 91 191 147 169 182 194 225 120 } \
        17 { 0 43 139 206 78 43 239 123 206 214 147 24 99 150 39 243 163 136 } \
        18 { 0 215 234 158 94 184 97 118 170 79 187 152 148 252 179 5 98 96 153 } \
        20 { 0 17 60 79 50 61 163 26 187 202 180 221 225 83 239 156 164 212 212 188 190 } \
        22 { 0 210 171 247 242 93 230 14 109 221 53 200 74 8 172 98 80 219 134 160 105 165 231 } \
        24 { 0 229 121 135 48 211 117 251 126 159 180 169 152 192 226 228 218 111 0 117 232 87 96 227 21 } \
        26 { 0 173 125 158 2 103 182 118 17 145 201 111 28 165 53 161 21 245 142 13 102 48 227 153 145 218 70 } \
        28 { 0 168 223 200 104 224 234 108 180 110 190 195 147 205 27 232 201 21 43 245 87 42 195 212 119 242 37 9 123 } \
        30 { 0 41 173 145 152 216 31 179 182 50 48 110 86 239 96 222 125 42 173 226 193 224 130 156 37 251 216 238 40 192 180 } \
    ]

    # GF(256) power values
    set gfPow {
        1 2 4 8 16 32 64 128 29 58 116 232 205 135 19 38 76 152 45 90 180 117 234 201 143 3 6 12 24 48 96 192 157 39 78 156 37 74 148 53 106 212 181 119 238 193 159 35 70 140 5 10 20 40 80 160 93 186 105 210 185 111 222 161 95 190 97 194 153 47 94 188 101 202 137 15 30 60 120 240 253 231 211 187 107 214 177 127 254 225 223 163 91 182 113 226 217 175 67 134 17 34 68 136 13 26 52 104 208 189 103 206 129 31 62 124 248 237 199 147 59 118 236 197 151 51 102 204 133 23 46 92 184 109 218 169 79 158 33 66 132 21 42 84 168 77 154 41 82 164 85 170 73 146 57 114 228 213 183 115 230 209 191 99 198 145 63 126 252 229 215 179 123 246 241 255 227 219 171 75 150 49 98 196 149 55 110 220 165 87 174 65 130 25 50 100 200 141 7 14 28 56 112 224 221 167 83 166 81 162 89 178 121 242 249 239 195 155 43 86 172 69 138 9 18 36 72 144 61 122 244 245 247 243 251 235 203 139 11 22 44 88 176 125 250 233 207 131 27 54 108 216 173 71 142 1
    }

    # GF(256) exponent values
    set gfExp {
        0 0 1 25 2 50 26 198 3 223 51 238 27 104 199 75 4 100 224 14 52 141 239 129 28 193 105 248 200 8 76 113 5 138 101 47 225 36 15 33 53 147 142 218 240 18 130 69 29 181 194 125 106 39 249 185 201 154 9 120 77 228 114 166 6 191 139 98 102 221 48 253 226 152 37 179 16 145 34 136 54 208 148 206 143 150 219 189 241 210 19 92 131 56 70 64 30 66 182 163 195 72 126 110 107 58 40 84 250 133 186 61 202 94 155 159 10 21 121 43 78 212 229 172 115 243 167 87 7 112 192 247 140 128 99 13 103 74 222 237 49 197 254 24 227 165 153 119 38 184 180 124 17 68 146 217 35 32 137 46 55 63 209 91 149 188 207 205 144 135 151 178 220 252 190 97 242 86 211 171 20 42 93 158 132 60 57 83 71 109 65 162 31 45 67 216 183 123 164 118 196 23 73 236 127 12 111 246 108 161 59 82 41 157 85 170 251 96 134 177 187 204 62 90 203 89 95 176 156 169 160 81 11 245 22 235 122 117 44 215 79 174 213 233 230 231 173 232 116 214 244 234 168 80 88 175
    }

    ##
    # Returns error correction code words for the specified part of the text.
    #
    # @param msg list of bytes for one of the reed-solomon blocks
    # @param eclen required number of error correction bytes
    #
    # @test
    #  - rsBlockErrorCorrection {32 91 11 120 209 114 220 77 67 64 236 17 236 17 236 17 236 17 236} 7 = {209 239 196 207 78 195 109}
    #  - rsBlockErrorCorrection {32 91 11 120 209 114 220 77 67 64 236 17 236 17 236 17} 10 = {196 35 39 119 235 215 231 226 93 23}
    #  - rsBlockErrorCorrection {32 65 205 69 41 220 46 128 236} 17 = {42 159 74 221 244 169 239 150 138 70 237 85 224 96 74 219 61}
    #  - rsBlockErrorCorrection {67 85 70 134 87 38 85 194 119 50 6 18 6 103 38} 18 = {213 199 11 45 115 247 241 223 229 248 154 117 154 111 86 161 111 39}
    #
    proc rsBlockErrorCorrection { msg eclen } {
        variable generatorPolynomials
        variable gfPow
        variable gfExp

        set gen [dict get $generatorPolynomials $eclen]

        set genLen [llength $gen]
        set extmsg [concat $msg [lrepeat $eclen 0]]
        set lastLeadTermIndex [expr { [llength $extmsg] - $genLen }]

        for { set leadTermIndex 0 } { $leadTermIndex <= $lastLeadTermIndex } { incr leadTermIndex } {
            # multiply the generator polynomial by the lead term of the message polynomial
            set leadCoef [lindex $extmsg $leadTermIndex]
            if { $leadCoef == 0 } {
                continue
            }
            set leadAExp [lindex $gfExp $leadCoef]

            for { set i 0 } { $i < $genLen } { incr i } {
                set exp [lindex $gen $i]
                set exp [expr { $exp + $leadAExp }]
                if { $exp > 255 } {
                    # Using a^255 == 1, split a^exp into a^255 * a^(exp - 255)
                    incr exp -255
                }
                set genCoef [lindex $gfPow $exp]
                set newCoef [expr { [lindex $extmsg $leadTermIndex+$i] ^ $genCoef }]
                lset extmsg $leadTermIndex+$i $newCoef
            }
        }
        return [lrange $extmsg $leadTermIndex end]
    }

    ##
    # Splits the encoded data into blocks, adds error correction data and finally
    # interleaves the result into a message.
    #
    # @param data encoded and padded to the required length data
    # @param version QR code version (0..39)
    # @param errorCorrectionLevel EC level (0 = L, 1 = M, 2 = Q, 3 = H)
    # @return list of numbers (bytes)
    #
    proc makeMessage { data version errorCorrectionLevel } {
        variable rsBlocks
        set rsBlocksInfo [lindex $rsBlocks $errorCorrectionLevel $version]
        lassign $rsBlocksInfo totalDataBytes numEcBytes
        if { [llength $data] != $totalDataBytes } {
            return -code error "invalid message - number of code words does not match the expected number for this version and error correction: [llength $data] vs $totalDataBytes"
        }
        set rsGroups [lrange $rsBlocksInfo 2 end]

        set dataBlocks [list]
        set ecBlocks   [list]
        set dataOffset 0
        foreach { numBlocks numBytes } $rsGroups {
            set lastIndexOffset [expr { $numBytes - 1 }]
            while { $numBlocks > 0 } {
                set blockData [lrange $data $dataOffset $dataOffset+$lastIndexOffset]
                lappend dataBlocks $blockData
                lappend ecBlocks [rsBlockErrorCorrection $blockData $numEcBytes]
                incr dataOffset $numBytes
                incr numBlocks -1
            }
        }

        # Interleave data and error correction bytes

        set numRows [llength $dataBlocks]
        set msg [list]

        set maxDataBlockLen [expr max([lindex $rsGroups 1],[lindex $rsBlocksInfo 3]) ]

        foreach { blocks numCols } [list $dataBlocks $maxDataBlockLen $ecBlocks $numEcBytes] {
            for { set c 0 } { $c < $numCols } { incr c } {
                for { set r 0 } { $r < $numRows } { incr r } {
                    set val [lindex $blocks $r $c]
                    if { $val != {} } {
                        lappend msg $val
                    }
                }
            }
        }
        # Not all versions need the remainder bits, but we'll add 8 of them anyway, so
        # that the bit placement proc would not need to worry about the end of the message
        lappend msg 0
        return $msg
    }
}