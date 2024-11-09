## HPC# overview

Burst uses a high performance subset of C# called High Performance C# (HPC#).

## Supported C# features in HPC#

HPC# supports most expressions and statements in C#. It supports the following:

|**Supported feature**|**Notes**|
|---|---|
|Extension methods.||
|Instance methods of structs.||
|Unsafe code and pointer manipulation.||
|Loading from static read-only fields.|For more information, see the documentation on [Static read-only fields and static constructors](csharp-static-read-only-support.md).|
|Regular C# control flows.|`if`<br/>`else`<br/>`switch`<br/>`case`<br/>`for`<br/>`while`<br/>`break`<br/>`continue`|
|`ref` and `out` parameters||
|`fixed` statements||
|Some [IL opcodes](https://docs.microsoft.com/en-us/dotnet/api/system.reflection.emit.opcodes?view=net-6.0).|`cpblk`<br/> `initblk`<br/> `sizeof`|
|`DLLImport` and internal calls.|For more information, see the documentation on [`DLLImport` and internal calls](csharp-burst-intrinsics-dllimport.md).|
|`try` and `finally` keywords. Burst also supports the associated [IDisposable](https://docs.microsoft.com/en-us/dotnet/api/system.idisposable?view=net-6.0) patterns, `using` and `foreach`.|If an exception happens in Burst, the behavior is different from .NET. In .NET, if an exception occurs inside a `try` block, control flow goes to the `finally` block. However, in Burst, if an exception happens inside or outside a `try` block, the exception throws as if any `finally` blocks do not exist.|
|Strings and `ProfilerMarker`.|For more information, see the documentation on [Support for Unity Profiler markers](debugging-profiling-tools.md#profiler-markers).|
|`throw` expressions.| Burst only supports simple `throw` patterns, for example, `throw new ArgumentException("Invalid argument")`. When you use simple patterns like this, Burst extracts the static string exception message and includes it in the generated code.|
|Strings and `Debug.Log`.|Only partially supported. For more information, see the documentation on [String support and `Debug.Log`](csharp-string-support.md). |

Burst also provides alternatives for some C# constructions not directly accessible to HPC#:

* [Function pointers](csharp-function-pointers.md) as an alternative to using delegates within HPC#
* [Shared static](csharp-shared-static.md) to access static mutable data from both C# and HPC#

### Exception expressions

Burst supports `throw` expressions for exceptions. Exceptions thrown in the **editor** can be caught by managed code, and are reported in the console window. Exceptions thrown in **player builds** will always cause the application to abort. Thus with Burst you should only use exceptions for exceptional behavior. To ensure that code doesn't end up relying on exceptions for things like general control flow, Burst produces the following warning on code that tries to `throw` within a method not attributed with `[Conditional("ENABLE_UNITY_COLLECTIONS_CHECKS")]`:

> Burst warning BC1370: An exception was thrown from a function without the correct [Conditional("ENABLE_UNITY_COLLECTIONS_CHECKS")] guard. Exceptions only work in the editor and so should be protected by this guard

## Unsupported C# features in HPC#

HPC# doesn't support the following C# features:

* Catching exceptions `catch` in a `try`/`catch`.
* Storing to static fields except via [Shared Static](csharp-shared-static.md)
* Any methods related to managed objects, for example, string methods.
