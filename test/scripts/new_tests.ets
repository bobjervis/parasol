run(filename: hmac_test.p)
run(filename: escapes.p)
run(filename: utf8stream.p)
run(filename: string16_test_1.p, arguments: src/lib/x86_64.p)
run(filename: string16_test_1.p, arguments: test/scripts/parasol_tests.ets)
run(filename: string16_test_2.p)
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

