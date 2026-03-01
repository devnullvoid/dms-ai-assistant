.pragma library
// Markdown to HTML converter for AI Assistant plugin
function markdownToHtml(text, colors) {
    if (!text) return "";

    const c = colors || {
        codeBg: "#20FFFFFF",
        inlineCodeBg: "#30FFFFFF",
        blockquoteBg: "transparent",
        blockquoteBorder: "#808080"
    };

    const placeholders = {};
    let placeholderIndex = 0;

    // Use a marker that does not contain any markdown-special characters (*, _, ~, [, |, etc.)
    const PH_PREFIX = "MSAPH";
    const PH_SUFFIX = "X";

    function createPlaceholder(content) {
        const id = `${PH_PREFIX}${placeholderIndex++}${PH_SUFFIX}`;
        placeholders[id] = content;
        return id;
    }

    // Strip the minimum common leading whitespace from all non-empty lines.
    // This dedents code blocks that are indented as part of a list item.
    function dedent(str) {
        const lines = str.split('\n');
        let minIndent = Infinity;
        for (let i = 0; i < lines.length; i++) {
            if (lines[i].trim() === '') continue;
            const indent = lines[i].match(/^(\s*)/)[1].length;
            if (indent < minIndent) minIndent = indent;
        }
        if (minIndent === 0 || minIndent === Infinity) return str;
        return lines.map(function(l) { return l.slice(minIndent); }).join('\n');
    }

    let html = text;

    // 1. Protect code blocks (must be first)
    html = html.replace(/```(?:([^\n]*)\n)?([\s\S]*?)```/g, (match, lang, code) => {
        const trimmedCode = dedent((code || "").replace(/^\n+|\n+$/g, ''));
        const escapedCode = trimmedCode.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        const labelText = lang && lang.trim() ? lang.trim() : "";
        const b64Code = Qt.btoa(trimmedCode);

        const codeBlockHtml =
            `<table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: ${c.codeBg}; margin: 8px 0; table-layout: fixed;">` +
                `<tr><td style="padding: 4px 10px 0 10px;">` +
                    `<table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin: 0; table-layout: fixed;">` +
                        `<tr>` +
                            `<td align="left" style="padding: 0;"><font size="1" color="#808080">${labelText}</font></td>` +
                            `<td align="right" style="padding: 0; width: 35px;"><a href="copy://${b64Code}" style="text-decoration: none;"><font size="1">[Copy]</font></a></td>` +
                        `</tr>` +
                    `</table>` +
                `</td></tr>` +
                `<tr><td style="padding: 0 10px 10px 10px;">` +
                    `<pre style="margin: 0; padding: 0; white-space: pre-wrap;"><code>${escapedCode}</code></pre>` +
                `</td></tr>` +
            `</table>`;

        return createPlaceholder(codeBlockHtml);
    });

    // 2. Protect inline code
    html = html.replace(/`([^`]+)`/g, (match, code) => {
        const escapedCode = code.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        const inlineHtml = `<span style="font-family: monospace; background-color: ${c.inlineCodeBg}; padding: 0 3px;">${escapedCode}</span>`;
        return createPlaceholder(inlineHtml);
    });

    // 3. Protect tables
    html = html.replace(/^\|(.+)\|\s*\n\|[\s\-:|]+\|\s*\n((?:\|.+\|\s*\n?)+)/gm, function(match, headerRow, dataRows) {
        const headers = headerRow.split('|').map(h => h.trim()).filter(h => h);
        const rows = dataRows.trim().split('\n').map(row => row.split('|').map(cell => cell.trim()).filter(cell => cell !== ''));
        let tableHtml = '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse: collapse; margin: 8px 0;">';
        tableHtml += '<tr>' + headers.map(header => `<th style="background-color: #30FFFFFF; padding: 5px;">${header}</th>`).join('') + '</tr>';
        rows.forEach(row => {
            tableHtml += '<tr>' + row.map(cell => `<td style="padding: 5px;">${cell}</td>`).join('') + '</tr>';
        });
        tableHtml += '</table>';
        return createPlaceholder(tableHtml) + "\n";
    });

    // 4. Escape remaining HTML entities
    html = html.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

    // 5. Process Markdown elements
    html = html.replace(/^######\s+([\s\S]*?)$/gm, '<h6 style="margin-bottom: 8px;"><font size="2">$1</font></h6>');
    html = html.replace(/^#####\s+([\s\S]*?)$/gm, '<h5 style="margin-bottom: 8px;"><i><font size="3">$1</font></i></h5>');
    html = html.replace(/^####\s+([\s\S]*?)$/gm, '<h4 style="margin-bottom: 8px;"><font size="3">$1</font></h4>');
    html = html.replace(/^###\s+([\s\S]*?)$/gm, '<h3 style="margin-bottom: 8px;"><font size="4">$1</font></h3>');
    html = html.replace(/^##\s+([\s\S]*?)$/gm, '<h2 style="margin-bottom: 8px;"><font size="5">$1</font></h2>');
    html = html.replace(/^#\s+([\s\S]*?)$/gm, '<h1 style="margin-bottom: 10px;"><font size="6">$1</font></h1>');
    html = html.replace(/^(\*{3,}|-{3,}|_{3,})$/gm, '<hr style="margin: 12px 0;"/>');
    
    html = html.replace(/\*\*\*(.*?)\*\*\*/g, '<b><i>$1</i></b>').replace(/\*\*(.*?)\*\*/g, '<b>$1</b>').replace(/\*(.*?)\*/g, '<i>$1</i>');
    html = html.replace(/___(.*?)___/g, '<b><i>$1</i></b>').replace(/__(.*?)__/g, '<b>$1</b>').replace(/_(.*?)_/g, '<i>$1</i>');
    html = html.replace(/~~(.*?)~~/g, '<s>$1</s>');
    html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
    
    html = html.replace(/^\s*[\*\-] \[([ xX])\] (.*?)$/gm, (match, checked, content) => `<li_task>${checked.toLowerCase() === 'x' ? '☑' : '☐'} ${content}</li_task>`);
    html = html.replace(/^\s*[\*\-] (.*?)$/gm, '<li_ul>$1</li_ul>').replace(/^\s*\d+\. (.*?)$/gm, '<li_ol>$1</li_ol>');

    const listHandler = (tag) => (match) => {
        const content = match.replace(new RegExp(`</?${tag}>`, 'g'), (t) => t.replace(tag, 'li')).replace(/\n/g, '');
        const style = tag === 'li_task' ? 'style="list-style-type: none; margin: 8px 0;"' : 'style="margin: 8px 0;"';
        return createPlaceholder(`<ul ${style}>${content}</ul>`) + "\n";
    };

    html = html.replace(/(<li_ul>[\s\S]*?<\/li_ul>\s*)+/g, listHandler('li_ul'));
    html = html.replace(/(<li_task>[\s\S]*?<\/li_task>\s*)+/g, listHandler('li_task'));

    // Ordered lists: use <ol start="N"> to continue numbering across block-level
    // placeholders (code blocks, tables) that may appear between list items.
    {
        const LI_OL_RE = /^<li_ol>([\s\S]*?)<\/li_ol>$/;
        const PH_RE = /^MSAPH\d+X$/;
        const lines = html.split('\n');
        const out = [];
        let i = 0;

        // Returns true if a <li_ol> line exists in lines[fromIdx..], skipping
        // blanks, block placeholders, and blockquote lines (all of which may
        // be inter-list content).
        function hasMoreListItems(fromIdx) {
            for (let j = fromIdx; j < lines.length; j++) {
                const t = lines[j].trim();
                if (LI_OL_RE.test(t)) return true;
                if (t === '' || PH_RE.test(t) || t.startsWith('&gt;')) continue;
                return false; // non-list, non-blank, non-placeholder, non-blockquote
            }
            return false;
        }

        while (i < lines.length) {
            const trimmed = lines[i].trim();

            if (!LI_OL_RE.test(trimmed)) {
                out.push(lines[i]);
                i++;
                continue;
            }

            // Collect the ordered list context.  Items may be separated by blank
            // lines and block-level placeholders; group into segments so we can
            // emit each run of items as <ol start="N"> to preserve numbering.
            const segments = [];
            let currentItems = [];
            let pendingBlocks = [];

            while (i < lines.length) {
                const cur = lines[i].trim();

                if (LI_OL_RE.test(cur)) {
                    if (pendingBlocks.length > 0) {
                        segments.push({ items: currentItems, blocks: pendingBlocks });
                        currentItems = [];
                        pendingBlocks = [];
                    }
                    currentItems.push('<li>' + cur.match(LI_OL_RE)[1] + '</li>');
                    i++;
                } else if (cur === '' || PH_RE.test(cur) || cur.startsWith('&gt;')) {
                    if (hasMoreListItems(i + 1)) {
                        // Block placeholders and blockquote lines are kept as
                        // inter-segment content.  cur is already trimmed, so
                        // &gt; lines will match the blockquote regex later.
                        if (cur !== '') pendingBlocks.push(cur);
                        i++; // blank lines are silently consumed
                    } else {
                        break; // block/blank/blockquote is after the list
                    }
                } else {
                    break;
                }
            }

            if (currentItems.length > 0) {
                segments.push({ items: currentItems, blocks: [] });
            }

            let olCounter = 1;
            for (let s = 0; s < segments.length; s++) {
                const seg = segments[s];
                const olHtml = '<ol start="' + olCounter + '" style="margin: 8px 0;">' +
                               seg.items.join('') + '</ol>';
                out.push(createPlaceholder(olHtml));
                olCounter += seg.items.length;
                for (let b = 0; b < seg.blocks.length; b++) {
                    out.push(seg.blocks[b]);
                }
            }
        }

        html = out.join('\n');
    }

    html = html.replace(/^&gt; (.*?)$/gm, '<bq_line>$1</bq_line>');
    html = html.replace(/(<bq_line>[\s\S]*?<\/bq_line>\s*)+/g, function(match) {
        const inner = match.replace(/<\/bq_line>\s*<bq_line>/g, '<br/>').replace(/<bq_line>/g, '').replace(/<\/bq_line>/g, '').trim();
        const bq = `<blockquote style="background-color: ${c.blockquoteBg}; border-left: 4px solid ${c.blockquoteBorder}; padding: 4px; margin: 8px 0;"><font color="#a0a0a0"><i>${inner}</i></font></blockquote>`;
        return createPlaceholder(bq) + "\n";
    });

    html = html.replace(/(^|[^"'>])((https?|file):\/\/[^\s<]+)/g, '$1<a href="$2">$2</a>');
    html = html.replace(/\n\n/g, '</p><p>').replace(/\n/g, '<br/>');
    if (!html.startsWith('<') && !html.startsWith(PH_PREFIX)) html = '<p>' + html + '</p>';

    const phRegex = new RegExp(`${PH_PREFIX}\\d+${PH_SUFFIX}`, 'g');
    let iterations = 0;
    while (phRegex.test(html) && iterations < 5) {
        html = html.replace(phRegex, (match) => placeholders[match] || match);
        iterations++;
    }

    html = html.replace(/<br\/>\s*(<table[^>]*>)/g, '$1').replace(/<br\/>\s*(<pre>)/g, '$1').replace(/<br\/>\s*(<ul[^>]*>)/g, '$1');
    html = html.replace(/<br\/>\s*(<ol[^>]*>)/g, '$1').replace(/<br\/>\s*(<blockquote[^>]*>)/g, '$1').replace(/<br\/>\s*(<table[^>]*>)/g, '$1');
    html = html.replace(/<br\/>\s*(<h[1-6][^>]*>)/g, '$1').replace(/<p>\s*<\/p>/g, '').replace(/<p>\s*<br\/>\s*<\/p>/g, '').replace(/(<br\/>){3,}/g, '<br/><br/>').replace(/(<\/p>)\s*(<p>)/g, '$1$2');
    
    return html.trim();
}
