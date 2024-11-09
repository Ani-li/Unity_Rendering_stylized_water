using System;
using System.Text.RegularExpressions;


namespace Unity.Burst.Editor
{
    internal struct SearchCriteria
    {
        internal string filter;
        internal bool isCaseSensitive;
        internal bool isWholeWords;
        internal bool isRegex;

        internal SearchCriteria(string keyword, bool caseSensitive, bool wholeWord, bool regex)
        {
            filter = keyword;
            isCaseSensitive = caseSensitive;
            isWholeWords = wholeWord;
            isRegex = regex;
        }

        internal bool Equals(SearchCriteria obj) =>
            filter == obj.filter && isCaseSensitive == obj.isCaseSensitive && isWholeWords == obj.isWholeWords && isRegex == obj.isRegex;

        public override bool Equals(object obj) =>
            obj is SearchCriteria other && Equals(other);

        public override int GetHashCode() => base.GetHashCode();
    }

    internal static class BurstStringSearch
    {
        /// <summary>
        /// Gets index of line end in given string, both absolute and relative to start of line.
        /// </summary>
        /// <param name="str">String to search in.</param>
        /// <param name="line">Line to get end index of.</param>
        /// <returns>(absolute line end index of string, line end index relative to line start).</returns>
        /// <exception cref="ArgumentOutOfRangeException">
        /// Argument must be greater than 0 and less than or equal to number of lines in
        /// <paramref name="str" />.
        /// </exception>
        internal static (int total, int relative) GetEndIndexOfPlainLine (string str, int line)
        {
            var lastIdx = -1;
            var newIdx = -1;

            for (var i = 0; i <= line; i++)
            {
                lastIdx = newIdx;
                newIdx = str.IndexOf('\n', lastIdx + 1);

                if (newIdx == -1 && i < line)
                {
                    throw new ArgumentOutOfRangeException(nameof(line),
                        "Argument must be greater than 0 and less than or equal to number of lines in str.");
                }
            }
            lastIdx++;
            return newIdx != -1 ? (newIdx, newIdx - lastIdx) : (str.Length - 1, str.Length - 1 - lastIdx);
        }

        /// <summary>
        /// Gets index of line end in given string, both absolute and relative to start of line.
        /// Adjusts the index so color tags are not included in relative index.
        /// </summary>
        /// <param name="str">String to search in.</param>
        /// <param name="line">Line to find end of in string.</param>
        /// <returns>(absolute line end index of string, line end index relative to line start adjusted for color tags).</returns>
        internal static (int total, int relative) GetEndIndexOfColoredLine(string str, int line)
        {
            var (total, relative) = GetEndIndexOfPlainLine(str, line);
            return RemoveColorTagFromIdx(str, total, relative);
        }

        /// <summary>
        /// Adjusts index of color tags on line.
        /// </summary>
        /// <remarks>Assumes that <see cref="tidx"/> is index of something not a color tag.</remarks>
        /// <param name="str">String containing the indexes.</param>
        /// <param name="tidx">Total index of line end.</param>
        /// <param name="ridx">Relative index of line end.</param>
        /// <returns>(<see cref="tidx"/>, <see cref="ridx"/>) adjusted for color tags on line.</returns>
        private static (int total, int relative) RemoveColorTagFromIdx(string str, int tidx, int ridx)
        {
            var lineStartIdx = tidx - ridx;
            var colorTagFiller = 0;

            var tmp = str.LastIndexOf("</color", tidx);
            var lastWasStart = true;
            var colorTagStart = str.LastIndexOf("<color=", tidx);

            if (tmp > colorTagStart)
            {
                // color tag end was closest
                lastWasStart = false;
                colorTagStart = tmp;
            }

            while (colorTagStart != -1 && colorTagStart >= lineStartIdx)
            {
                var colorTagEnd = str.IndexOf('>', colorTagStart);
                // +1 as the index is zero based.
                colorTagFiller += colorTagEnd - colorTagStart + 1;

                if (lastWasStart)
                {
                    colorTagStart = str.LastIndexOf("</color", colorTagStart);
                    lastWasStart = false;
                }
                else
                {
                    colorTagStart = str.LastIndexOf("<color=", colorTagStart);
                    lastWasStart = true;
                }
            }
            return (tidx - colorTagFiller, ridx - colorTagFiller);
        }

        /// <summary>
        /// Finds the zero indexed line number of given <see cref="matchIdx"/>.
        /// </summary>
        /// <param name="str">String to search in.</param>
        /// <param name="matchIdx">Index to find line number of.</param>
        /// <returns>Line number of given index in string.</returns>
        internal static int FindLineNr(string str, int matchIdx)
        {
            var lineNr = 0;
            var idxn = str.IndexOf('\n');

            while (idxn != -1 && idxn < matchIdx)
            {
                lineNr++;
                idxn = str.IndexOf('\n', idxn + 1);
            }

            return lineNr;
        }

        /// <summary>
        /// Finds first match of <see cref="criteria"/> in given string.
        /// </summary>
        /// <param name="str">String to search in.</param>
        /// <param name="criteria">Search options.</param>
        /// <param name="regx">Used when <see cref="criteria"/> specifies regex search.</param>
        /// <param name="startIdx">Index to start the search at.</param>
        /// <returns>(start index of match, length of match)</returns>
        internal static (int idx, int length) FindMatch(string str, SearchCriteria criteria, Regex regx, int startIdx = 0)
        {
            var idx = -1;
            var len = 0;

            if (criteria.isRegex)
            {
                // regex will have the appropriate options in it if isCaseSensitive or/and isWholeWords is true.
                var res = regx.Match(str, startIdx);

                if (res.Success) (idx, len) = (res.Index, res.Length);
            }
            else if (criteria.isWholeWords)
            {
                (idx, len) = (IndexOfWholeWord(str, startIdx, criteria.filter, criteria.isCaseSensitive
                    ? StringComparison.InvariantCulture
                    : StringComparison.InvariantCultureIgnoreCase), criteria.filter.Length);
            }
            else
            {
                (idx, len) = (str.IndexOf(criteria.filter, startIdx, criteria.isCaseSensitive
                    ? StringComparison.InvariantCulture
                    : StringComparison.InvariantCultureIgnoreCase), criteria.filter.Length);
            }

            return (idx, len);
        }

        /// <summary>
        /// Finds index of <see cref="filter"/> matching for whole words.
        /// </summary>
        /// <param name="str">String to search in.</param>
        /// <param name="startIdx">Index to start search from.</param>
        /// <param name="filter">Key to search for.</param>
        /// <param name="opt">Options for string comparison.</param>
        /// <returns>Index of match or -1.</returns>
        private static int IndexOfWholeWord(string str, int startIdx, string filter, StringComparison opt)
        {
            const string wholeWordMatch = @"\w";

            var j = startIdx;
            var filterLen = filter.Length;
            var strLen = str.Length;
            while (j < strLen && (j = str.IndexOf(filter, j, opt)) >= 0)
            {
                var noPrior = true;
                if (j != 0)
                {
                    var frontBorder = str[j - 1];
                    noPrior = !Regex.IsMatch(frontBorder.ToString(), wholeWordMatch);
                }

                var noAfter = true;
                if (j + filterLen != strLen)
                {
                    var endBorder = str[j + filterLen];
                    noAfter = !Regex.IsMatch(endBorder.ToString(), wholeWordMatch);
                }

                if (noPrior && noAfter) return j;

                j++;
            }
            return -1;
        }
    }
}