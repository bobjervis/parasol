compile(expect: fail, message: DISALLOWED_ANNOTATION) { "@Shape @Shape class foo {}" }
compile(expect: fail, message: UNRECOGNIZED_ANNOTATION) { "@Sxp class foo {}" }
