# firmware-deep-dive
Bare-metal firmware engineering and low-level deep dive projects (Outside of work).

## Code format

The repository uses [`.clang-format`](.clang-format) for C/C++ source files in
numbered project directories. On Windows, run `./format.cmd` to format files or
`./format.cmd -Check` to check them without editing. The same check runs on
pull requests with clang-format 22.1.4.

Assembly and linker scripts are outside the clang-format scope. The format
check passes when no C/C++ sources have been added yet.
