#!/bin/sh

test_description='test json-writer JSON generation'
. ./test-lib.sh

test_expect_success 'unit test of json-writer routines' '
	test-json-writer -u
'

test_expect_success 'trivial object' '
	cat >expect <<-\EOF &&
	{}
	EOF
	test-json-writer >actual \
		@object \
		@end &&
	test_cmp expect actual
'

test_expect_success 'trivial array' '
	cat >expect <<-\EOF &&
	[]
	EOF
	test-json-writer >actual \
		@array \
		@end &&
	test_cmp expect actual
'

test_expect_success 'simple object' '
	cat >expect <<-\EOF &&
	{"a":"abc","b":42,"c":3.14,"d":true,"e":false,"f":null}
	EOF
	test-json-writer >actual \
		@object \
			@object-string a abc \
			@object-int b 42 \
			@object-double c 2 3.140 \
			@object-true d \
			@object-false e \
			@object-null f \
		@end &&
	test_cmp expect actual
'

test_expect_success 'simple array' '
	cat >expect <<-\EOF &&
	["abc",42,3.14,true,false,null]
	EOF
	test-json-writer >actual \
		@array \
			@array-string abc \
			@array-int 42 \
			@array-double 2 3.140 \
			@array-true \
			@array-false \
			@array-null \
		@end &&
	test_cmp expect actual
'

test_expect_success 'escape quoting string' '
	cat >expect <<-\EOF &&
	{"a":"abc\\def"}
	EOF
	test-json-writer >actual \
		@object \
			@object-string a abc\\def \
		@end &&
	test_cmp expect actual
'

test_expect_success 'escape quoting string 2' '
	cat >expect <<-\EOF &&
	{"a":"abc\"def"}
	EOF
	test-json-writer >actual \
		@object \
			@object-string a abc\"def \
		@end &&
	test_cmp expect actual
'

test_expect_success 'nested inline object' '
	cat >expect <<-\EOF &&
	{"a":"abc","b":42,"sub1":{"c":3.14,"d":true,"sub2":{"e":false,"f":null}}}
	EOF
	test-json-writer >actual \
		@object \
			@object-string a abc \
			@object-int b 42 \
			@object-object "sub1" \
				@object-double c 2 3.140 \
				@object-true d \
				@object-object "sub2" \
					@object-false e \
					@object-null f \
				@end \
			@end \
		@end &&
	test_cmp expect actual
'

test_expect_success 'nested inline array' '
	cat >expect <<-\EOF &&
	["abc",42,[3.14,true,[false,null]]]
	EOF
	test-json-writer >actual \
		@array \
			@array-string abc \
			@array-int 42 \
			@array-array \
				@array-double 2 3.140 \
				@array-true \
				@array-array \
					@array-false \
					@array-null \
				@end \
			@end \
		@end &&
	test_cmp expect actual
'

test_expect_success 'nested inline object and array' '
	cat >expect <<-\EOF &&
	{"a":"abc","b":42,"sub1":{"c":3.14,"d":true,"sub2":[false,null]}}
	EOF
	test-json-writer >actual \
		@object \
			@object-string a abc \
			@object-int b 42 \
			@object-object "sub1" \
				@object-double c 2 3.140 \
				@object-true d \
				@object-array "sub2" \
					@array-false \
					@array-null \
				@end \
			@end \
		@end &&
	test_cmp expect actual
'

test_expect_success 'nested inline object and array 2' '
	cat >expect <<-\EOF &&
	{"a":"abc","b":42,"sub1":{"c":3.14,"d":true,"sub2":[false,{"g":0,"h":1},null]}}
	EOF
	test-json-writer >actual \
		@object \
			@object-string a abc \
			@object-int b 42 \
			@object-object "sub1" \
				@object-double c 2 3.140 \
				@object-true d \
				@object-array "sub2" \
					@array-false \
					@array-object \
						@object-int g 0 \
						@object-int h 1 \
					@end \
					@array-null \
				@end \
			@end \
		@end &&
	test_cmp expect actual
'

test_expect_success 'pretty nested inline object and array 2' '
	sed -e "s/^|//" >expect <<-\EOF &&
	|{
	|  "a": "abc",
	|  "b": 42,
	|  "sub1": {
	|    "c": 3.14,
	|    "d": true,
	|    "sub2": [
	|      false,
	|      {
	|        "g": 0,
	|        "h": 1
	|      },
	|      null
	|    ]
	|  }
	|}
	EOF
	test-json-writer >actual \
		--pretty \
		@object \
			@object-string a abc \
			@object-int b 42 \
			@object-object "sub1" \
				@object-double c 2 3.140 \
				@object-true d \
				@object-array "sub2" \
					@array-false \
					@array-object \
						@object-int g 0 \
						@object-int h 1 \
					@end \
					@array-null \
				@end \
			@end \
		@end &&
	test_cmp expect actual
'

test_expect_success 'bogus: array element in object' '
	test_must_fail test-json-writer >actual \
		@object \
			@array-string abc \
		@end
'

test_expect_success 'bogus: object element in array' '
	test_must_fail test-json-writer >actual \
		@array \
			@object-string a abc \
		@end
'

test_expect_success 'bogus: unterminated child' '
	test_must_fail test-json-writer >actual \
		@object \
			@object-object "sub1" \
			@end
'

test_expect_success 'bogus: unterminted top level' '
	test_must_fail test-json-writer >actual \
		@object
'

test_expect_success 'bogus: first term' '
	test_must_fail test-json-writer >actual \
		@object-int a 0
'

test_expect_success 'bogus: missing val param' '
	test_must_fail test-json-writer >actual \
		@object \
			@object-int a \
		@end
'

test_expect_success 'bogus: extra token after val param' '
	test_must_fail test-json-writer >actual \
		@object \
			@object-int a 0 1 \
		@end
'

test_done
