// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "Freakz2z/tracecite"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/Freakz2z/tracecite"

license = "Apache-2.0"

keywords = [ "agent", "trace", "citation", "evidence" ]

preferred_target = "native"

description = "Deterministic checks for citations in agent execution traces"

import {
  "moonbitlang/async@0.22.1",
}
