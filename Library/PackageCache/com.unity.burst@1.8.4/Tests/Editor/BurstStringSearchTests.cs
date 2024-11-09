using System;
using System.Text;
using System.Text.RegularExpressions;
using NUnit.Framework;
using Unity.Burst;
using Unity.Burst.Editor;

public class BurstStringSearchTests
{
    private BurstDisassembler GetDisassemblerandText(string compileTargetName, int debugLvl, out string textToRender)
    {
        // Get target job assembly:
        var assemblies = BurstReflection.EditorAssembliesThatCanPossiblyContainJobs;
        var result = BurstReflection.FindExecuteMethods(assemblies, BurstReflectionAssemblyOptions.None);
        var compileTarget =  result.CompileTargets.Find(x => x.GetDisplayName() == compileTargetName);

        Assert.IsTrue(compileTarget != default, $"Could not find compile target: {compileTarget}");

        BurstDisassembler disassembler = new BurstDisassembler();

        var options = new StringBuilder();

        compileTarget.Options.TryGetOptions(compileTarget.JobType, true, out string defaultOptions);
        options.AppendLine(defaultOptions);
        // Disables the 2 current warnings generated from code (since they clutter up the inspector display)
        // BC1370 - throw inside code not guarded with ConditionalSafetyCheck attribute
        // BC1322 - loop intrinsic on loop that has been optimised away
        options.AppendLine($"{BurstCompilerOptions.GetOption(BurstCompilerOptions.OptionDisableWarnings, "BC1370;BC1322")}");

        options.AppendLine($"{BurstCompilerOptions.GetOption(BurstCompilerOptions.OptionTarget, BurstTargetCpu.X64_SSE4)}");

        options.AppendLine($"{BurstCompilerOptions.GetOption(BurstCompilerOptions.OptionDebug, $"{debugLvl}")}");

        var baseOptions = options.ToString();

        var append = BurstInspectorGUI.GetDisasmOptions()[(int)DisassemblyKind.Asm];

        // Setup disAssembler with the job:
        compileTarget.RawDisassembly = BurstInspectorGUI.GetDisassembly(compileTarget.Method, baseOptions + append);
        textToRender = compileTarget.RawDisassembly.TrimStart('\n');

        return disassembler;
    }

    [Test]
    public void FindLineNrTest()
    {
        // Load in a test text
        var disassembler = GetDisassemblerandText("BurstInspectorGUITests.MyJob - (IJob)", 1, out string textToRender);
        disassembler.Initialize(textToRender, BurstDisassembler.AsmKind.Intel, true, true);

        var text = disassembler.GetOrRenderBlockToText(0);

        // Call find line nr for:
        //  first line
        //  Around middle
        //  Last line
        Assert.AreEqual(0, BurstStringSearch.FindLineNr(text, text.IndexOf('\n') - 1), "Couldn't find line 0");

        Assert.AreEqual(2, BurstStringSearch.FindLineNr(text, text.IndexOf('\n', text.IndexOf('\n') + 1) + 1), "Couldn't find line in middle");

        Assert.AreEqual(disassembler.Blocks[0].Length-1, BurstStringSearch.FindLineNr(text, text.Length-1), "Couldn't find last line");
    }

    [Test]
    public void GetEndIndexOfPlainLineTest()
    {
        Assert.AreEqual(("This\nIs\nPerfect".Length-1, 6),
            BurstStringSearch.GetEndIndexOfPlainLine("This\nIs\nPerfect", 2),
            "Failed finding in well formed string");

        const string text1 = "No line endings";
        Assert.AreEqual((text1.Length-1, text1.Length-1),
            BurstStringSearch.GetEndIndexOfPlainLine(text1, 0),
            "Failed for missing line ending");

        const string text2 = "No Line endings too many lines";
        Assert.Throws<ArgumentOutOfRangeException>(() => BurstStringSearch.GetEndIndexOfPlainLine(text2, 2),
            "Failed for missing line ending and too high line number");

        const string text3 = "Line ending\n";
        Assert.AreEqual((text3.Length-1, text3.Length-1),
            BurstStringSearch.GetEndIndexOfPlainLine(text3, 0),
            "Failed with line ending");

        const string text4 = "Line ending too many lines\n";
        Assert.Throws<ArgumentOutOfRangeException>(() => BurstStringSearch.GetEndIndexOfPlainLine(text4, 2),
            "Failed with line endings and too high line number");
    }

    [Test]
    public void FindMatchTest()
    {
        _ = GetDisassemblerandText("BurstInspectorGUITests.MyJob - (IJob)", 2, out var textToRender);

        var expectedNormal = textToRender.IndexOf("def");
        var tmp = Regex.Match(textToRender, @"\bdef\b");
        var expectedWhole = tmp.Success ? tmp.Index : -1;


        // Normal search
        Assert.AreEqual((expectedNormal, 3),
            BurstStringSearch.FindMatch(textToRender,
                new SearchCriteria("def", false, false, false), default),
            "Standard search failed"); // standard search: Match def in .endef
        Assert.AreEqual((expectedWhole, 3),
            BurstStringSearch.FindMatch(textToRender,
                new SearchCriteria("def", false, true, false), default),
            "Standard whole words failed"); // whole word search: Match def in .def

        // Regex search
        const RegexOptions opt = RegexOptions.CultureInvariant;
        Assert.AreEqual((expectedNormal, 3),
            BurstStringSearch.FindMatch(textToRender,
                new SearchCriteria("def", false, false, true),
                new Regex("def", opt | RegexOptions.IgnoreCase)),
            "Regex search failed"); // standard search: Match def in .endef
        Assert.AreEqual((expectedWhole, tmp.Success ? 3 : 0),
            BurstStringSearch.FindMatch(textToRender,
                new SearchCriteria(@"\bdef\b", false, true, true),
                new Regex(@"\bdef\b", opt)),
            "Regex whole word failed"); // whole word search: Match def in .def

        // Across lines and blocks
        Assert.AreEqual((12, 4),
            BurstStringSearch.FindMatch(textToRender,
                new SearchCriteria(@"t[\n]+..", false, false, true),
                new Regex(@"t[\n]+..", opt | RegexOptions.IgnoreCase)),
            "Regex across lines failed");
    }
}
