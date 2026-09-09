*gotodiff.vim*  Navigate from a diff buffer to the files it describes

==============================================================================
CONTENTS                                                   *gotodiff-contents*

    1. Introduction ......................... |gotodiff-introduction|
    2. Mappings ............................. |gotodiff-mappings|
    3. Commands ............................. |gotodiff-commands|
    4. Command line file names .............. |gotodiff-cmdline-file|

==============================================================================
1. INTRODUCTION                                        *gotodiff-introduction*

gotodiff.vim makes `diff` buffers usable for navigation, the way `netrw` buffers
and the |quickfix| list are: jump from a line in a diff to the corresponding
line in the file it describes, or load every added or modified line into the
|quickfix| or |location-list|.

Everything is buffer local to buffers with 'filetype' `diff`.

==============================================================================
2. MAPPINGS                                                *gotodiff-mappings*

                                                                *gotodiff_gd*
gd                      Edit the file under the cursor at the corresponding
                        line.  Same as |:GtdEdit|.

                                                            *gotodiff_CTRL-W_d*
CTRL-W d                Open the file under the cursor at the corresponding
                        line in a split.  Same as |:GtdNew|.

                                                                *gotodiff_gC*
gC                      Populate the |quickfix| list.  Same as |:GtdQflist|.

                                                                *gotodiff_gL*
gL                      Populate the |location-list|.  Same as |:GtdLoclist|.

==============================================================================
3. COMMANDS                                                *gotodiff-commands*

                                                                    *:GtdEdit*
:GtdEdit                Edit the file under the cursor at the corresponding
                        line, with the column preserved (the diff indicator
                        gutter is accounted for).

                                                                   *:GtdPedit*
:GtdPedit               As |:GtdEdit|, but open the file in the preview
                        window.

                                                                     *:GtdNew*
:GtdNew                 As |:GtdEdit|, but open the file in a split.

                                                                 *:GtdQflist*
:GtdQflist              Add every added or modified line in the diff (but not
                        removed lines) to the |quickfix| list.  This allows
                        |:cdo| to edit each of those lines, e.g. >
                            :GtdQflist
                            :cdo s/foo/bar
<                       replaces `foo` with `bar` on every added or modified
                        line in the diff.

                                                                *:GtdLoclist*
:GtdLoclist             As |:GtdQflist|, but populate the |location-list| of
                        the current window.

==============================================================================
4. COMMAND LINE FILE NAMES                            *gotodiff-cmdline-file*

                                                          *gotodiff_c_CTRL-R_CTRL-F*
CTRL-R CTRL-F           As |c_CTRL-R_CTRL-F|, but strip the `a/` or `b/` diff
                        prefix from the file name under the cursor.  With the
                        cursor on >
                            a/Sidewinder/UiRandomize.maxpat
<                       it inserts >
                            Sidewinder/UiRandomize.maxpat
<
                        A file name without a diff prefix is inserted
                        unchanged.  The cursor is left after the inserted
                        text, so typing can continue as usual.

 vim:tw=78:ts=8:ft=help:norl:
