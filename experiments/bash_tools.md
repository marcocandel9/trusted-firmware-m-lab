# Useful bash scripts used to navigate tf-m files

## Find the files in a dir recursively containing a specific string specified in regex
```
find <dir-where-to-search> -type f -name <filename filter> -exec grep -nHE '[REGEX PATTERN]' {} +
```
## Save unstaged working-tree changes to a patch file
```bash
git -C <repository-directory> diff -- <pathspec> > <output-file>.patch
```
-C <repository-directory>: runs Git as if started in that directory.
diff: compares the working tree with the staging area (index).
--: separates Git options and revisions from file paths.
<pathspec>: selects the files or directories to compare; it is relative to
the directory specified with -C.
>: redirects the diff output to the patch file.
This command does not include staged changes or untracked files.

## Search bytes for strings with a size min of 4 bytes in a compiled binary file
````bash
arm-none-eabi-strings <binfile> | grep -i '<string>'
-i makes the search case insensitive
```
