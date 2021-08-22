[CReferences::] C References.

How changes to storage objects are translated into C.

@ References identify storage objects which are being written to or otherwise
modified, rather than having their current contents read.

There are seven possible ways to modify something identified by a reference,
and we need constants to identify these ways at runtime:

= (text to inform7_clib.h)
#define i7_lvalue_SET 1
#define i7_lvalue_PREDEC 2
#define i7_lvalue_POSTDEC 3
#define i7_lvalue_PREINC 4
#define i7_lvalue_POSTINC 5
#define i7_lvalue_SETBIT 6
#define i7_lvalue_CLEARBIT 7
=

@ Those seven ways correspond to seven Inter primitives, with the following
signatures:
= (text)
primitive !store         ref val -> val
primitive !preincrement  ref -> val
primitive !postincrement ref -> val
primitive !predecrement  ref -> val
primitive !postdecrement ref -> val
primitive !setbit        ref val -> void
primitive !clearbit      ref val -> void
=
Since C functions can have their return values freely ignored, we will in fact
implement |!setbit| and |!clearbit| as if they too had the signature
|ref val -> val|.

For all these primitives, then, the first operand A1 is a |ref|, and the following
function should be used to generate from it:

=
void CReferences::A1_as_ref(code_generation *gen, inter_tree_node *P) {
	C_GEN_DATA(memdata.next_node_is_a_ref) = TRUE;
	CodeGen::FC::frame(gen, InterTree::first_child(P));
	C_GEN_DATA(memdata.next_node_is_a_ref) = FALSE;
}

@ That sets a temporary mode which is immediately detected and cleared by
the generator for whatever A1 actually is. That generator is expected to call
this function to detect whether it's a ref. In this mode, A1 is compiled not
to a valid C expression to evaluate the contents of A1, but instead to a
function call which will modify A1, and which is missing one or two final
arguments.

Note that the mode is auto-exited at once. This is all a bit clumsy, but is
correct.

=
int CReferences::am_I_a_ref(code_generation *gen) {
	int answer = C_GEN_DATA(memdata.next_node_is_a_ref);
	C_GEN_DATA(memdata.next_node_is_a_ref) = FALSE;
	return answer;
}

@ So, then, here goes:

=
int CReferences::compile_primitive(code_generation *gen, inter_ti bip, inter_tree_node *P) {
	text_stream *OUT = CodeGen::current(gen);
	text_stream *store_form = NULL;
	switch (bip) {
		case STORE_BIP:			store_form = I"i7_lvalue_SET"; break;
		case PREINCREMENT_BIP:	store_form = I"i7_lvalue_PREINC"; break;
		case POSTINCREMENT_BIP:	store_form = I"i7_lvalue_POSTINC"; break;
		case PREDECREMENT_BIP:	store_form = I"i7_lvalue_PREDEC"; break;
		case POSTDECREMENT_BIP:	store_form = I"i7_lvalue_POSTDEC"; break;
		case SETBIT_BIP:		store_form = I"i7_lvalue_SETBIT"; break;
		case CLEARBIT_BIP:		store_form = I"i7_lvalue_CLEARBIT"; break;
		default: return NOT_APPLICABLE;
	}
	if (store_form) @<This does indeed modify a value by reference@>;
	return FALSE;
}

@ Some storage objects, like variables, can be generated to C code which works
in either an lvalue or rvalue context. For example, the Inter variable |frog|
generates just as the C variable |i7_mgl_frog|.[1] It's then fine to generate
code like either |10 + i7_mgl_frog|, where it is used in a |val| context, or
like |i7_mgl_frog++|, where it is used in a |ref| context.

But other storage objects are not so lucky, and those need to generate to
different function calls, one used in a |ref| setting, one used in a |val|.
That's what is done by the "A1 as ref" mode set up above.

[1] In real life, do not mangle frogs. See C. S. Lewis, "Perelandra", 1943.

@<This does indeed modify a value by reference@> =
	inter_tree_node *ref = InterTree::first_child(P);
	if ((CMemoryModel::handle_store_by_ref(gen, ref)) ||
		(CObjectModel::handle_store_by_ref(gen, ref))) {
		@<Handle the ref using the incomplete-function mode@>;
	} else {
		@<Handle the ref with C code working either as lvalue or rvalue@>;
	}

@<Handle the ref using the incomplete-function mode@> =
	WRITE("("); CReferences::A1_as_ref(gen, P);
	if (bip == STORE_BIP) { INV_A2; } else { WRITE("0"); }
	WRITE(", %S))", store_form);

@<Handle the ref with C code working either as lvalue or rvalue@> =
	switch (bip) {
		case PREINCREMENT_BIP:	WRITE("++("); INV_A1; WRITE(")"); break;
		case POSTINCREMENT_BIP:	WRITE("("); INV_A1; WRITE(")++"); break;
		case PREDECREMENT_BIP:	WRITE("--("); INV_A1; WRITE(")"); break;
		case POSTDECREMENT_BIP:	WRITE("("); INV_A1; WRITE(")--"); break;
		case STORE_BIP:			WRITE("("); INV_A1; WRITE(" = "); INV_A2; WRITE(")"); break;
		case SETBIT_BIP:		INV_A1; WRITE(" = "); INV_A1; WRITE(" | "); INV_A2; break;
		case CLEARBIT_BIP:		INV_A1; WRITE(" = "); INV_A1; WRITE(" &~ ("); INV_A2; WRITE(")"); break;
	}