// Verify that comments get stripped and we have 3 identifier tokens.
scan(tokens: 3) {
"	// Hello world
	a b c"
}

scan (tokens: 1) {
0x123456789abcdef
}
// The g should start a second, identifier token
scan (tokens: 2) {
0x123456789abcdefg
}
// There must be an exponent after the e
scan (expect: fail) { 1.0e }
scan (expect: fail) { 0x }

scan(tokens: 1) {
0x0e
}

scan(tokens: 0) {
}
scan(tokens:0) { "// Just a line comment" }
scan(tokens:0) { "/* Just a block comment /* with nesting */ */   " }

	// Various identifier tokens
	
scan(tokens: 1, value:"abc"){ abc }
scan(tokens: 1, value:"Abc"){ Abc }
scan(tokens: 1, value:"aBc"){ aBc }
scan(tokens: 1, value:"β") { β }
scan(tokens: 1, value:"a123"){ a123 }
scan(tokens: 1, value:"_"){ _ }
scan(tokens: 1, value:"a_"){ a_ }
scan(tokens: 1, value:"a"){ `a` }
scan(tokens: 1, value:"1"){ `1` }
scan(tokens: 1, value:"%r$"){ `%r$` }

	// Various integer tokens

scan(tokens: 1, value:"123"){ 123 }
scan(tokens: 1, value:"0"){ 0 }
scan(tokens: 1, value:"0x0"){ 0x0 }
scan(tokens: 1, value:"0x0abcef"){ 0x0abcef }
scan(tokens: 1, value:"23۷5"){ 23۷5 }

	// Various floating point tokens

scan(tokens: 1, value:"123.0"){ 123.0 }
scan(tokens: 1, value:"123.0f"){ 123.0f }
scan(tokens: 1, value:"123.0e+34"){ 123.0e+34 }
scan(tokens: 3){ e+34 }		// Not a number, identifier e, + and integer 34 tokens
scan(tokens: 1, value:".123"){ .123 }
scan(tokens: 1, value:".0"){ .0 }
scan(tokens: 1, value:"0"){ 0. }

	// Various character tokens

scan(tokens: 1, value:"a") { "'a'"}
scan(tokens: 1, value:"\\0") { "'\\0'" }
scan(tokens: 1, value:"\\a") { "'\\a'" }
scan(tokens: 1, value:"\\b") { "'\\b'" }
scan(tokens: 1, value:"\\f") { "'\\f'" }
scan(tokens: 1, value:"\\n") { "'\\n'" }
scan(tokens: 1, value:"\\r") { "'\\r'" }
scan(tokens: 1, value:"\\t") { "'\\t'" }
scan(tokens: 1, value:"\\v") { "'\\v'" }
scan(tokens: 1, value:"\\u123f") { "'\\u123f'" }
scan(tokens: 1, value:"\\x23") { "'\\x23'" }
scan(tokens: 1, value:"\\'") { "'\\''" }
scan(tokens: 1, value:"\\\"") { "'\\\"'" }
scan(tokens: 1, value:"\"") { "'\"'" }

	// Various string tokens

scan(tokens: 1, value:"a") { '"a"' }
scan(tokens: 1, value:"\\0") { '"\\0"' }
scan(tokens: 1, value:"\\a") { '"\\a"' }
scan(tokens: 1, value:"\\b") { '"\\b"' }
scan(tokens: 1, value:"\\f") { '"\\f"' }
scan(tokens: 1, value:"\\n") { '"\\n"' }
scan(tokens: 1, value:"\\r") { '"\\r"' }
scan(tokens: 1, value:"\\t") { '"\\t"' }
scan(tokens: 1, value:"\\v") { '"\\v"' }
scan(tokens: 1, value:"\\u123f") { '"\\u123f"' }
scan(tokens: 1, value:"\\x23") { '"\\x23"' }
scan(tokens: 1, value:"\\'") { '"\\\'"' }
scan(tokens: 1, value:"\\\"") { '"\\\""' }
scan(tokens: 1, value:"\'") { '"\'"' }
scan(tokens: 1, value:"ab") { '"a\\\nb"' }
scan(tokens: 1, value:"ab") { '"a\\\r\nb"' }

	// Various annotations
	
scan(tokens: 1, value:"annotation"){ @annotation }
scan(tokens: 1, value:"a123"){ @a123 }
scan(tokens: 1, value:"_"){ @_ }

scan(tokens: 1){ ; }
scan(tokens: 1){ : }
scan(tokens: 1){ . }
scan(tokens: 1){ .. }
scan(tokens: 1){ ... }
scan(tokens: 1){ "(" }
scan(tokens: 1){ ")" }
scan(tokens: 1){ "{" }
scan(tokens: 1){ "}" }
scan(tokens: 1){ "[" }
scan(tokens: 1){ "]" }
scan(tokens: 1){ "<" }
scan(tokens: 1){ ">" }
scan(tokens: 1){ , }
scan(tokens: 1){ / }
scan(tokens: 1){ % }
scan(tokens: 1){ * }
scan(tokens: 1){ + }
scan(tokens: 1){ - }
scan(tokens: 1){ & }
scan(tokens: 1){ ^ }
scan(tokens: 1){ | }
scan(tokens: 1){ ! }
scan(tokens: 1){ = }
scan(tokens: 1){ := }
scan(tokens: 1){ ? }
scan(tokens: 1){ ~ }
scan(tokens: 1){ /= }
scan(tokens: 1){ %= }
scan(tokens: 1){ *= }
scan(tokens: 1){ += }
scan(tokens: 1){ -= }
scan(tokens: 1){ &= }
scan(tokens: 1){ ^= }
scan(tokens: 1){ |= }
scan(tokens: 1){ == }
scan(tokens: 1){ === }
scan(tokens: 1){ <= }
scan(tokens: 1){ >= }
scan(tokens: 1){ <> }
scan(tokens: 1){ <>= }
scan(tokens: 1){ != }
scan(tokens: 1){ !== }
scan(tokens: 1){ !< }
scan(tokens: 1){ !> }
scan(tokens: 1){ !<= }
scan(tokens: 1){ !>= }
scan(tokens: 1){ !<> }
scan(tokens: 1){ !<>= }
scan(tokens: 1){ << }
scan(tokens: 1){ " >>" }
scan(tokens: 1){ " >>>" }
scan(tokens: 2){ >> }
scan(tokens: 3){ >>> }
scan(tokens: 1){ <<= }
scan(tokens: 1){ <<= }
scan(tokens: 1){ " >>=" }
scan(tokens: 1){ " >>>=" }
scan(tokens: 2){ >>= }
scan(tokens: 3){ >>>= }
scan(tokens: 1){ && }
scan(tokens: 1){ || }
scan(tokens: 1){ ++ }
scan(tokens: 1){ -- }

scan(keyword: abstract) { abstract }
scan(keyword: break) { break }
scan(keyword: bytes) { bytes }
scan(keyword: case) { case }
scan(keyword: catch) { catch }
scan(keyword: class) { class }
scan(keyword: continue) { continue }
scan(keyword: default) { default }
scan(keyword: delete) { delete }
scan(keyword: do) { do }
scan(keyword: else) { else }
scan(keyword: enum) { enum }
scan(keyword: extends) { extends }
scan(keyword: false) { false }
scan(keyword: final) { final }
scan(keyword: finally) { finally }
scan(keyword: flags) { flags }
scan(keyword: for) { for }
scan(keyword: function) { function }
scan(keyword: if) { if }
scan(keyword: implements) { implements }
scan(keyword: import) { import }
scan(keyword: interface) { interface }
scan(keyword: lock) { lock }
scan(keyword: monitor) { monitor }
scan(keyword: namespace) { namespace }
scan(keyword: new) { new }
scan(keyword: null) { null }
scan(keyword: private) { private }
scan(keyword: protected) { protected }
scan(keyword: public) { public }
scan(keyword: return) { return }
scan(keyword: static) { static }
scan(keyword: super) { super }
scan(keyword: switch) { switch }
scan(keyword: this) { this }
scan(keyword: throw) { throw }
scan(keyword: true) { true }
scan(keyword: try) { try }
scan(keyword: while) { while }

scan(expect:fail, character:0)
scan(expect:fail, character:1)
scan(expect:fail, character:2)
scan(expect:fail, character:3)
scan(expect:fail, character:4)
scan(expect:fail, character:5)
scan(expect:fail, character:6)
scan(expect:fail, character:7)
scan(expect:fail, character:8)
scan(expect:fail, character:11)
scan(expect:fail, character:14)
scan(expect:fail, character:15)
scan(expect:fail, character:16)
scan(expect:fail, character:17)
scan(expect:fail, character:18)
scan(expect:fail, character:19)
scan(expect:fail, character:20)
scan(expect:fail, character:21)
scan(expect:fail, character:22)
scan(expect:fail, character:23)
scan(expect:fail, character:24)
scan(expect:fail, character:25)
scan(expect:fail, character:26)
scan(expect:fail, character:27)
scan(expect:fail, character:28)
scan(expect:fail, character:29)
scan(expect:fail, character:30)
scan(expect:fail, character:31)
scan(expect:fail) { '#' }
scan(expect:fail) { '$' }
scan(expect:fail) { '\\' }
scan(expect:fail, character:127)
scan(expect:fail, character:128)
scan(expect:fail, character:708)
scan(expect:fail, character:1644)


codePoint(value:03) { "\x03" }
codePoint(value:20) { " " }
codePoint(value:35) { "5" }
codePoint(value:80) { "\xc2\x80" }
codePoint(value:373) { "\xcd\xb3" }
codePoint(value:2136) { "\xe2\x84\xb6" }
codePoint(value:aa7a) { "\xea\xa9\xba" }
codePoint(value:10a7c) { "\xf0\x90\xa9\xbc" } // old south arabain letter theth
codePoint(value:2fa1d) { "\xf0\xaf\xa8\x9d" } // CJK COMPATIBILITY IDEOGRAPH-2FA1D
codePoint(value:7fffffff) { "\xff" }
codePoint(value:7fffffff) { "\xaf" }
codePoint(value:'7fffffff,7fffffff') { "\xf0\xf0" }
codePoint(value:'7fffffff,40') { "\xf0\x40" }

