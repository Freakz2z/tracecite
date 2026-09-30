# Third-party notices

TraceCite's own code is licensed under [Apache-2.0](LICENSE). This file records
upstream components used by the library and the default native CLI build.
Upstream copyright, permission and disclaimer text is retained verbatim in
[third_party/licenses](third_party/licenses); origins and SHA-256 values are in
[third_party/provenance.json](third_party/provenance.json).

| Component | Audited version / origin | License and retained material |
| --- | --- | --- |
| moonbitlang/async | Resolved 0.22.4; module requests at least 0.22.1 | Apache-2.0; async-LICENSE.txt |
| bobzhang/html_parser | 0.2.0 | Apache-2.0; html-parser-LICENSE.txt |
| JustHTML | Attribution supplied with the MoonBit HTML port | MIT; JustHTML-MIT.txt, including the upstream inspiration/test attributions |
| moonbitlang/core | SDK 0.10.14+7d59c7ec9 | Apache-2.0 and upstream NOTICE; core-LICENSE.txt, core-NOTICE.txt |
| MoonBit native runtime | Same SDK; Copyright 2026 International Digital Economy Academy | Apache-2.0; runtime copyright header is collected from the build SDK |
| libbacktrace | Linked SDK library; independent version unspecified | BSD-3-Clause; libbacktrace-BSD.txt |
| mimalloc | SDK native allocator; independent embedded version unspecified | MIT; mimalloc-LICENSE.txt |
| simdutf | SDK native UTF implementation; independent embedded version unspecified | Apache-2.0 OR MIT; both upstream license texts retained |

The core NOTICE includes the upstream notices for adaptations from V8/fdlibm,
Go, musl/Arm, Sun and FreeBSD. It is retained in full rather than shortened to
only the functions TraceCite calls. The JustHTML Python implementation and the
upstream HTML test suites are not copied into TraceCite's runtime; the port's
upstream attribution is retained conservatively.

The mimalloc and simdutf origin commits identify **license snapshots**, not the
exact releases embedded in the SDK. The SDK does not supply their independent
version metadata. The recorded compiler/core identity identifies the audited
build; these versions must not be inferred from the license download date.

## Native distribution

`scripts/package.sh` copies the actual resolved dependency licenses, the build
SDK's core LICENSE/NOTICE, and runtime/libbacktrace copyright headers. Missing
required materials stop packaging. The checked-in mimalloc/simdutf notices are
verified against their recorded digests. The archive contains LICENSE,
THIRD_PARTY_NOTICES.md, licenses/ and BUILD-INFO.json, with component identities
and hashes for all payload files. The `third_party/` links above describe the
source repository; the native archive uses `licenses/` directly.

The standard build links MoonBit runtime, libbacktrace, mimalloc and simdutf
objects; it does not ship the compiler, Python, Node or a copy of OpenSSL.
Online HTTPS checks load the host system's TLS library and use its certificate
store: Linux libssl.so.3 / libssl.so.1.1, or the macOS system libssl dylib.
Offline checks do not require TLS. System libraries and their licenses remain
part of the operating system distribution.

If the SDK or allocator/link settings change, review that build's component
list and update the notice inventory before distributing it. This inventory
documents the default build, rather than certifying every custom toolchain.

## Other development resources

GitHub Actions, the MoonBit compiler and Python are build/test tools and are
not redistributed in the CLI archive. External audit files are bounded
attributed quotation samples with source URLs and fixed revisions, described
in [the audit record](docs/external-audit.md). No external repository or private
Agent session is bundled wholesale.
