[SimpleStages::] Read, Move, Wipe, Stop.

Four simple pipeline stages.

@ =
void SimpleStages::create_pipeline_stages(void) {
	ParsingPipelines::new_stage(I"stop", SimpleStages::run_stop_stage, NO_STAGE_ARG, FALSE);
	ParsingPipelines::new_stage(I"wipe", SimpleStages::run_wipe_stage, NO_STAGE_ARG, FALSE);
	ParsingPipelines::new_stage(I"read", SimpleStages::run_read_stage, FILE_STAGE_ARG, TRUE);
	ParsingPipelines::new_stage(I"move", SimpleStages::run_move_stage, GENERAL_STAGE_ARG, TRUE);
}

@h Read.

=
int SimpleStages::run_read_stage(pipeline_step *step) {
	filename *F = step->ephemera.parsed_filename;
	if (Inter::Binary::test_file(F)) Inter::Binary::read(step->ephemera.repository, F);
	else Inter::Textual::read(step->ephemera.repository, F);
	return TRUE;
}

@h Move.

=
int SimpleStages::run_move_stage(pipeline_step *step) {
	match_results mr = Regexp::create_mr();
	inter_package *pack = NULL;
	if (Regexp::match(&mr, step->step_argument, L"(%d):(%c+)")) {
		int from_rep = Str::atoi(mr.exp[0], 0);
		if (step->ephemera.pipeline->ephemera.repositories[from_rep] == NULL)
			internal_error("no such repository");
		pack = Inter::Packages::by_url(
			step->ephemera.pipeline->ephemera.repositories[from_rep], mr.exp[1]);
	}
	Regexp::dispose_of(&mr);
	if (pack == NULL) internal_error("not a package");
	Inter::Transmigration::move(pack, Site::main_package(step->ephemera.repository), FALSE);

	return TRUE;
}

@h Wipe.

=
int SimpleStages::run_wipe_stage(pipeline_step *step) {
	Inter::Warehouse::wipe();
	return TRUE;
}

@h Stop.
The "stop" stage is special, in that it always returns false, thus stopping
the pipeline:

=
int SimpleStages::run_stop_stage(pipeline_step *step) {
	return FALSE;
}