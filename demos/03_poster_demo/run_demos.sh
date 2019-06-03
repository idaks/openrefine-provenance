#!/usr/bin/env bash
#
# ./run_demos.sh &> demos.txt

source ../settings.sh

DATASET_ID=${1:-'dataset_1'}

xsb --quietload --noprompt --nofeedback --nobanner << END_XSB_STDIN

['$RULES_DIR/general_rules'].
['$RULES_DIR/query_rules'].
['$RULES_DIR/report_rules'].
['${DATASET_ID}'].

%set_prolog_flag(unknown, fail).

%-------------------------------------------------------------------------------
demo_banner( 'Demo 1', 'What columns in the original dataset were renamed?').
[user].

column_name_at_state(Column, State, Name) :-
    column_schema_at_state(Schema, Column, State),
    column_schema(Schema, _, _, _, Name, _, _).

column_rename(State1, Name1, State2, Name2) :-
    column_name_at_state(Column, State1, Name1),
    column_name_at_state(Column, State2, Name2),
    State2 > State1,
    Name2 \== Name1.

d1(Dataset) :-
    import_state(_, Dataset, Array, ImportState),
    final_array_state(Array, FinalState),
    column_rename(ImportState, OriginalName, FinalState, FinalName),
    fmt_write('The column originally named "%S\" was ultimately named "%S".\n', fmt(OriginalName, FinalName)),
    fail
    ;
    true.

end_of_file.
d1(${DATASET_ID}).
%-------------------------------------------------------------------------------


%-------------------------------------------------------------------------------
demo_banner( 'Demo 2', 'What columns in the final dataset contain cells with updated values?').
[user].

:- table column_with_updated_cell_value/1.
column_with_updated_cell_value(Column) :-
    content(_, Cell, _, _, PrevContentId),
    PrevContentId \== nil,
    cell(Cell, Column, _).

d2(Dataset) :-
    import_state(_, Dataset, Array, _),
    final_array_state(Array, FinalState),
    column_with_updated_cell_value(Column),
    column_name(Column, FinalState, ColumnName),
    fmt_write('The column named "%S\" in the final data set contains cells with updated values.\n', fmt(ColumnName)),
    fail
    ;
    true.

end_of_file.
d2(${DATASET_ID}).
%-------------------------------------------------------------------------------

%-------------------------------------------------------------------------------
demo_banner( 'Demo 3', 'What cells were assigned new values during the same step?').
[user].

cell_with_update_at_state(Cell, State) :-
    content(_, Cell, State, _, PrevContentId),
    PrevContentId \== nil.

:- table state_with_multiple_cell_updates/1.
state_with_multiple_cell_updates(State) :-
    cell_with_update_at_state(Cell1, State),
    cell_with_update_at_state(Cell2, State),
    Cell1 \== Cell2.

cell_change_at_state(Cell, State, ValueText1, ValueText2) :-
    content(_, Cell, State, Value2, PrevContentId),
    content(PrevContentId, _, _, Value1, _),
    value(Value1, ValueText1),
    value(Value2, ValueText2).

cell_indices(Cell, State, ColIndex, RowIndex) :-
    %fmt_write('cell_indices -> Cell=%S\n', arg(Cell)),
    cell(Cell, ColId, RowId),
    column_index(ColId, State, ColIndex),
    row_index(RowId, State, RowIndex).

d3(Dataset) :-
    import_state(_, Dataset, Array, _),
    state(State, Array, _),
    state_with_multiple_cell_updates(State),
    fmt_write('Multiple cells were assigned new values at step %S:\n\n', arg(State)),
    cell_change_at_state(Cell, State, ValueText1, ValueText2),
    cell_indices(Cell, State, ColIndex, RowIndex),
    fmt_write('Cell in column %S of row %S was updated from "%S" to "%S"\n', arg(ColIndex, RowIndex, ValueText1, ValueText2)),
    fail
    ;
    true.

end_of_file.
d3(${DATASET_ID}).
%-------------------------------------------------------------------------------


%-------------------------------------------------------------------------------
demo_banner( 'Demo 4', 'What fraction of columns had their schemas changed or contain values with updated cells?').
[user].

:- table column_with_changed_type_or_name/2.
column_with_changed_type_or_name(Array, Column) :-
    column(Column, Array),
    column_schema(_, Column, _, Type, Name, _, PrevColSchema),
    column_schema(PrevColSchema, _, _, PrevType, PrevName, _, _),
    (Type \== PrevType ; Name \== PrevName).

:- table column_with_updated_cell/2.
column_with_updated_cell(Array, Column) :-
    column(Column, Array),
    content(_, Cell, _, _, PrevContent),
    PrevContent \== nil,
    cell(Cell, Column, _).

:- table column_with_updated_schema_or_cell/2.
column_with_updated_schema_or_cell(Array, Column) :-
    column_with_changed_type_or_name(Array, Column)
    ;
    column_with_updated_cell(Array, Column).

d4(Dataset) :-
    import_state(_, Dataset, Array, _),
    count(column(_, Array), NumColumns),
    count(column_with_changed_type_or_name(Array, _), NumColumnsWithChangedSchemas),
    count(column_with_updated_cell(Array, _), NumColumnsWithUpdatedCells),
    count(column_with_updated_schema_or_cell(Array, _), NumColumnsWithUpdatedSchemaOrCells),
    PercentageColumnsChanged is NumColumnsWithUpdatedSchemaOrCells / NumColumns * 100,
    fmt_write('A total of %S columns had their schemas updated.\n', arg(NumColumnsWithChangedSchemas)),
    fmt_write('A total of %S columns contain cells with updated values.\n', arg(NumColumnsWithUpdatedCells)),
    fmt_write('A total of %S columns (%.2f percent) contain cells with updated schemas or values.\n', arg(NumColumnsWithUpdatedSchemaOrCells, PercentageColumnsChanged)),
    fail
    ;
    true.

end_of_file.
d4(${DATASET_ID}).
%-------------------------------------------------------------------------------


nl.

END_XSB_STDIN

