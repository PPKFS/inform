[Unit::] Unit Tests.

How we shall test it.

@h Lexer.

@d SPOTTED_MC 0x00010000

=

source_file *Unit::feed_open_file_into_lexer_full

(filename *F, FILE *handle,
    text_stream *leaf, int documentation_only, general_pointer ref, int expand) {
    source_file *sf = CREATE(source_file);
    sf->words_of_source = 0;
    sf->words_of_quoted_text = 0;
    sf->your_ref = ref;
    sf->name = F;
    sf->handle = handle;
    source_location top_of_file;
    int cr, last_cr, next_cr, read_cr, newline_char = 0;

    unicode_file_buffer ufb = TextFiles::create_ufb();

    top_of_file.file_of_origin = sf;
    top_of_file.line_number = 1;

    Lexer::feed_begins(top_of_file);
		if (expand) lexer_divide_strings_at_text_substitutions = TRUE;
    if (documentation_only) lexer_wait_for_dashes = TRUE;

    last_cr = ' '; cr = ' '; next_cr = TextFiles::utf8_fgetc(sf->handle, NULL, TRUE, &ufb);
    if (next_cr == 0xFEFF) next_cr = TextFiles::utf8_fgetc(sf->handle, NULL, TRUE, &ufb);
    if (next_cr != EOF)
        while (((read_cr = TextFiles::utf8_fgetc(sf->handle, NULL, TRUE, &ufb)), next_cr) != EOF) {
            last_cr = cr; cr = next_cr; next_cr = read_cr;
            switch(cr) {
                case '\x0a':
                    if (newline_char == '\x0d') {
                        newline_char = 0; continue;
                    }
                    newline_char = cr; cr = '\n';
                    break;
                case '\x0d':
                    if (newline_char == '\x0a') {
                        newline_char = 0; continue;
                    }
                    newline_char = cr; cr = '\n';
                    break;
                default:
                    newline_char = 0;
                    break;
            }
            Lexer::feed_triplet(last_cr, cr, next_cr);
        }

    sf->text_read = Lexer::feed_ends(TRUE, leaf);

    LOOP_THROUGH_WORDING(wc, sf->text_read)
        sf->words_of_source += TextFromFiles::word_count(wc);
    return sf;
}

source_file *Unit::feed_into_lexer_full(filename *F, general_pointer ref, int expand) {
    FILE *handle = Filenames::fopen(F, "r");
    if (handle == NULL) return NULL;
    source_file *sf = Unit::feed_open_file_into_lexer_full(F, handle,
        Filenames::get_leafname(F), FALSE, ref, expand);
    fclose(handle);
    return sf;
}

void Unit::test_lexer(text_stream *arg, int expand) {
	filename *F = Filenames::from_text(arg);
	source_file *sf = Unit::feed_into_lexer_full(F, NULL_GENERAL_POINTER, expand);
	if (sf == NULL) PRINT("File has failed to open\n");
	else {
		PRINT("%d words\n", sf->words_of_source);
		int c = 0;
		LOOP_THROUGH_WORDING(wn, sf->text_read) {
			vocabulary_entry *ve = Lexer::word(wn);
			if ((ve) && (Vocabulary::test_vflags(ve, SPOTTED_MC) == 0)) {
				PRINT("¶%w¶ ", ve->exemplar);
				Vocabulary::set_flags(ve, SPOTTED_MC);
				c++;
			}
		}
	}
    for (int i=0; i<lexer_wordcount; i++)
        PRINT("¶%+N¶ ¶%N¶ %02x\n", i, i, Lexer::break_before(i));
}

@h Preform.

=
<text> ::=
	invade ... |              ==> { TRUE, - }; PRINT("Invading %+W\n", GET_RW(<text>, 1));
	proclaim <any-integer> |  ==> { TRUE, - }; PRINT("It is now %d.\n", R[1]);
	announce <quoted-text> |  ==> { TRUE, - }; PRINT("Attention: %w.\n", Lexer::word_text(R[1]));
	<declaration> |           ==> { TRUE, - }; PRINT("Dominion %d now independent\n", R[1]);
	...                       ==> { FALSE, - }; PRINT("Unknown command\n");

<declaration> ::=
	declare <dominion> independent	==>	{ pass 1 }

<dominion> ::=
	canada |
	india |
	malaya

@ =
void Unit::test_preform(text_stream *arg) {
	pathname *P = Pathnames::from_text(I"services");
	P = Pathnames::down(P, I"words-test");
	P = Pathnames::down(P, I"Tangled");
	filename *S = Filenames::in(P, I"Syntax.preform");
	LoadPreform::load(S, NULL);

	filename *F = Filenames::from_text(arg);
	source_file *sf = TextFromFiles::feed_into_lexer(F, NULL_GENERAL_POINTER);
	if (sf == NULL) PRINT("File has failed to open\n");
	else {
		LOOP_THROUGH_WORDING(i, sf->text_read) {
			if (Lexer::word(i) == PARBREAK_V) continue;
			int j = i;
			while ((j <= Wordings::last_wn(sf->text_read))
				&& (Lexer::word(j) != PARBREAK_V)) j++;
			wording W = Wordings::new(i, j-1);
			i = j-1;
			PRINT("command: %W: ", W);
			if (<text>(W) == FALSE) PRINT("Failed Preform\n");
		}
	}
}