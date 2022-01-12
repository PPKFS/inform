[SynopticTables::] Tables.

To compile the main/synoptic/tables submodule.

@ Our inventory |inv| already contains a list |inv->table_nodes| of all packages
in the tree with type |_table|.

=
void SynopticTables::compile(inter_tree *I, pipeline_step *step, tree_inventory *inv) {
	if (TreeLists::len(inv->table_nodes) > 0) @<Assign unique table ID numbers@>;
	if (TreeLists::len(inv->table_column_nodes) > 0) @<Assign unique table column ID numbers@>;
	if (TreeLists::len(inv->table_column_usage_nodes) > 0) {
		TreeLists::sort(inv->table_column_usage_nodes, MakeSynopticModuleStage::module_order);
		for (int i=0; i<TreeLists::len(inv->table_column_usage_nodes); i++) {
			inter_package *pack = Inter::Package::defined_by_frame(inv->table_column_usage_nodes->list[i].node);
			inter_tree_node *ID = Synoptic::get_definition(pack, I"column_identity");
			inter_symbol *id_s = NULL;
			if (ID->W.data[DATA_CONST_IFLD] == ALIAS_IVAL)
				id_s = InterSymbolsTables::symbol_from_id(Inter::Packages::scope(pack), ID->W.data[DATA_CONST_IFLD+1]);
			if (id_s == NULL) internal_error("column_identity not an ALIAS_IVAL");
			ID = Inter::Symbols::definition(id_s);
			inter_tree_node *D = Synoptic::get_definition(pack, I"column_bits");
			D->W.data[DATA_CONST_IFLD+1] += ID->W.data[DATA_CONST_IFLD+1];
		}
	}
	@<Define TABLEOFTABLES array@>;
	@<Define PRINT_TABLE function@>;
	@<Define TC_KOV function@>;
	@<Define TB_BLANKS array@>;
	@<Define RANKING_TABLE constant@>;
}

@ Each table package contains a numeric constant with the symbol name |table_id|.
We want to ensure that these ID numbers are contiguous from 1 and never duplicated,
so we change the values of these constants accordingly.

@<Assign unique table ID numbers@> =
	TreeLists::sort(inv->table_nodes, MakeSynopticModuleStage::module_order);
	for (int i=0; i<TreeLists::len(inv->table_nodes); i++) {
		inter_package *pack = Inter::Package::defined_by_frame(inv->table_nodes->list[i].node);
		inter_tree_node *D = Synoptic::get_definition(pack, I"table_id");
		D->W.data[DATA_CONST_IFLD+1] = (inter_ti) (i + 1);
	}

@ And similarly for columns. The runtime code uses a range of unique ID numbers
to represent table columns; these can't simply be addresses of the data because
two uses of columns called "population" in different tables need to have the
same ID in each context. (They need to run from 100 upward because numbers 0 to
99 refer to columns by index within the current table: see //assertions: Tables//.)

@<Assign unique table column ID numbers@> =
	TreeLists::sort(inv->table_column_nodes, MakeSynopticModuleStage::module_order);
	for (int i=0; i<TreeLists::len(inv->table_column_nodes); i++) {
		inter_package *pack = Inter::Package::defined_by_frame(inv->table_column_nodes->list[i].node);
		inter_tree_node *D = Synoptic::get_definition(pack, I"table_column_id");
		D->W.data[DATA_CONST_IFLD+1] = (inter_ti) (i + 100);
	}

@<Define TABLEOFTABLES array@> =
	inter_name *iname = HierarchyLocations::find(I, TABLEOFTABLES_HL);
	Synoptic::begin_array(I, step, iname);
	Synoptic::symbol_entry(InterNames::to_symbol(
		HierarchyLocations::find(I, THEEMPTYTABLE_HL)));
	for (int i=0; i<TreeLists::len(inv->table_nodes); i++) {
		inter_package *pack = Inter::Package::defined_by_frame(inv->table_nodes->list[i].node);
		inter_symbol *value_s = Metadata::read_symbol(pack, I"^value");
		Synoptic::symbol_entry(value_s);
	}
	Synoptic::numeric_entry(0);
	Synoptic::numeric_entry(0);
	Synoptic::end_array(I);

@<Define PRINT_TABLE function@> =
	inter_name *iname = HierarchyLocations::find(I, PRINT_TABLE_HL);
	Synoptic::begin_function(I, iname);
	inter_symbol *T_s = Synoptic::local(I, I"T", NULL);
	Produce::inv_primitive(I, SWITCH_BIP);
	Produce::down(I);
		Produce::val_symbol(I, K_value, T_s);
		Produce::code(I);
		Produce::down(I);
			Produce::inv_primitive(I, CASE_BIP);
			Produce::down(I);
				Produce::val_iname(I, K_value,
					HierarchyLocations::find(I, THEEMPTYTABLE_HL));
				Produce::code(I);
				Produce::down(I);
					Produce::inv_primitive(I, PRINT_BIP);
					Produce::down(I);
						Produce::val_text(I, I"(the empty table)");
					Produce::up(I);
					Produce::rtrue(I);
				Produce::up(I);
			Produce::up(I);

		for (int i=0; i<TreeLists::len(inv->table_nodes); i++) {
			inter_package *pack = Inter::Package::defined_by_frame(inv->table_nodes->list[i].node);
			inter_symbol *value_s = Metadata::read_symbol(pack, I"^value");
			text_stream *printed_name = Metadata::read_textual(pack, I"^printed_name");
			Produce::inv_primitive(I, CASE_BIP);
			Produce::down(I);
				Produce::val_symbol(I, K_value, value_s);
				Produce::code(I);
				Produce::down(I);
					Produce::inv_primitive(I, PRINT_BIP);
					Produce::down(I);
						Produce::val_text(I, printed_name);
					Produce::up(I);
					Produce::rtrue(I);
				Produce::up(I);
			Produce::up(I);
		}

			Produce::inv_primitive(I, DEFAULT_BIP);
			Produce::down(I);
				Produce::code(I);
				Produce::down(I);
					Produce::inv_primitive(I, PRINT_BIP);
					Produce::down(I);
						Produce::val_text(I, I"** No such table **");
					Produce::up(I);
					Produce::rtrue(I);
				Produce::up(I);
			Produce::up(I);
		Produce::up(I);
	Produce::up(I);
	Synoptic::end_function(I, step, iname);

@<Define TC_KOV function@> =
	inter_name *iname = HierarchyLocations::find(I, TC_KOV_HL);
	Synoptic::begin_function(I, iname);
	inter_symbol *tc_s = Synoptic::local(I, I"tc", NULL);
	inter_symbol *unk_s = Synoptic::local(I, I"unk", NULL);
	Produce::inv_primitive(I, SWITCH_BIP);
	Produce::down(I);
		Produce::val_symbol(I, K_value, tc_s);
		Produce::code(I);
		Produce::down(I);

	for (int i=0; i<TreeLists::len(inv->table_column_nodes); i++) {
		inter_package *pack =
			Inter::Package::defined_by_frame(inv->table_column_nodes->list[i].node);
		inter_symbol *tc_kind = Metadata::read_symbol(pack, I"^column_kind");
		Produce::inv_primitive(I, CASE_BIP);
		Produce::down(I);
			Produce::val(I, K_value, LITERAL_IVAL, (inter_ti) (i + 100));
			Produce::code(I);
			Produce::down(I);
				Produce::inv_primitive(I, RETURN_BIP);
				Produce::down(I);
					Produce::val_symbol(I, K_value, tc_kind);
				Produce::up(I);
			Produce::up(I);
		Produce::up(I);
	}

		Produce::up(I);
	Produce::up(I);
	Produce::inv_primitive(I, RETURN_BIP);
	Produce::down(I);
		Produce::val_symbol(I, K_value, unk_s);
	Produce::up(I);
	Synoptic::end_function(I, step, iname);

@<Define TB_BLANKS array@> =
	inter_name *iname = HierarchyLocations::find(I, TB_BLANKS_HL);
	Produce::annotate_iname_i(iname, BYTEARRAY_IANN, 1);
	Synoptic::begin_array(I, step, iname);
	inter_ti hwm = 0;
	for (int i=0; i<TreeLists::len(inv->table_column_usage_nodes); i++) {
		inter_package *pack =
			Inter::Package::defined_by_frame(inv->table_column_usage_nodes->list[i].node);
		inter_tree_node *D = Synoptic::get_optional_definition(pack, I"column_blanks");
		if (D) {
			D->W.data[DATA_CONST_IFLD+1] = hwm;
			inter_tree_node *B = Synoptic::get_definition(pack, I"^column_blank_data");
			for (int i=DATA_CONST_IFLD; i<B->W.extent; i=i+2) {
				Synoptic::numeric_entry(B->W.data[i+1]);
				hwm++;
			}
		}
	}
	Synoptic::numeric_entry(0);
	Synoptic::numeric_entry(0);
	Synoptic::end_array(I);

@<Define RANKING_TABLE constant@> =
	inter_name *iname = HierarchyLocations::find(I, RANKING_TABLE_HL);
	int found = FALSE;
	for (int i=0; i<TreeLists::len(inv->table_nodes); i++) {
		inter_package *pack =
			Inter::Package::defined_by_frame(inv->table_nodes->list[i].node);
		if (Metadata::read_optional_numeric(pack, I"^ranking_table")) {
			inter_symbol *value_s = Metadata::read_symbol(pack, I"^value");
			Produce::symbol_constant(I, iname, K_value, value_s);
			found = TRUE;
			break;
		}
	}
	if (found == FALSE) Produce::numeric_constant(I, iname, K_value, 0);