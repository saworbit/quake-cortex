/*
    cortex_config.qc - Compiler Configuration

    Sets up compiler pragmas for the Cortex mod.
    We need to disable some strict warnings that occur in the base QuakeWorld code.
*/

// Disable warnings that are errors in the base QW code
#pragma warning disable Q105  // too few parameters - base QW code has this issue
#pragma warning disable Q106  // assignment to const - base QW code does this
