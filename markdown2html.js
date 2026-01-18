.pragma library
// Markdown to HTML converter for AI Assistant plugin
// Supports headers, bold, italic, strikethrough, code blocks with language labels,
// tables, task lists, links, blockquotes, and horizontal rules
function markdownToHtml(text, colors) {
    if (!text) return "";

    const c = colors || {
        codeBg: "#20FFFFFF",
        inlineCodeBg: "#30FFFFFF",
        blockquoteBg: "transparent",
        blockquoteBorder: "#808080"
    };

    // Store code blocks and inline code to protect them from further processing
    const codeBlocks = [];
    const inlineCode = [];
    const protectedBlocks = [];
    let blockIndex = 0;
    let inlineIndex = 0;
    let protectedIndex = 0;

    // First, extract and replace code blocks with placeholders
    // Regex matches ```[language]\n[content]```
    let html = text.replace(/```(?:([^\n]*)\n)?([\s\S]*?)```/g, (match, lang, code) => {
        // Trim leading and trailing blank lines only
        const trimmedCode = (code || "").replace(/^\n+|\n+$/g, '');
        // Escape HTML entities in code
        const escapedCode = trimmedCode.replace(/&/g, '&amp;')
                                       .replace(/</g, '&lt;')
                                       .replace(/>/g, '&gt;');

        // Add language label if specified
        const languageLabel = lang && lang.trim()
            ? `<div style="font-size: 9px; opacity: 0.6; padding-bottom: 4px;">${lang.trim()}</div>`
            : '';

        // Add consistent margins to code blocks
        codeBlocks.push(`<div style="background-color: ${c.codeBg}; padding: 10px; margin: 8px 0;">${languageLabel}<pre style="margin: 0;"><code>${escapedCode}</code></pre></div>`);
        return `\x00CODEBLOCK${blockIndex++}\x00`;
    });

    // Extract and replace inline code
    html = html.replace(/`([^`]+)`/g, (match, code) => {
        // Escape HTML entities in code
        const escapedCode = code.replace(/&/g, '&amp;')
                               .replace(/</g, '&lt;')
                               .replace(/>/g, '&gt;');
        // Use span with background color for highlighting.
        inlineCode.push(`<span style="font-family: monospace; background-color: ${c.inlineCodeBg};">&nbsp;${escapedCode}&nbsp;</span>`);
        return `\x00INLINECODE${inlineIndex++}\x00`;
    });

    // Extract and protect tables BEFORE HTML entity escaping
    html = html.replace(/^\|(.+)\|\s*\n\|[\s\-:|]+\|\s*\n((?:\|.+\|\s*\n?)+)/gm, function(match, headerRow, dataRows) {
        // Parse header
        const headers = headerRow.split('|').map(h => h.trim()).filter(h => h);

        // Parse data rows
        const rows = dataRows.trim().split('\n').map(row => {
            return row.split('|').map(cell => cell.trim()).filter(cell => cell !== '');
        });

        // Build HTML table
        let tableHtml = '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse: collapse; margin: 8px 0;">';

        // Add header
        tableHtml += '<tr>';
        headers.forEach(header => {
            tableHtml += `<th style="background-color: #30FFFFFF; padding: 5px;">${header}</th>`;
        });
        tableHtml += '</tr>';

        // Add data rows
        rows.forEach(row => {
            tableHtml += '<tr>';
            row.forEach(cell => {
                tableHtml += `<td style="padding: 5px;">${cell}</td>`;
            });
            tableHtml += '</tr>';
        });

        tableHtml += '</table>';

        // Protect table from further processing
        protectedBlocks.push(tableHtml);
        return `\x00PROTECTEDBLOCK${protectedIndex++}\x00\n`;
    });

    // Now process everything else
    // Escape HTML entities (but not in code blocks or tables)
    html = html.replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;');

    // Headers
    // Use <font size> to force sizing as QML CSS support for headers is flaky
    // Add margin-bottom for spacing instead of <br/> to avoid cleanup issues
    // Use [\s\S]*? instead of .*? to handle any whitespace at end of line
    html = html.replace(/^######\s+([\s\S]*?)$/gm, '<h6 style="margin-bottom: 8px;"><font size="2">$1</font></h6>');
    html = html.replace(/^#####\s+([\s\S]*?)$/gm, '<h5 style="margin-bottom: 8px;"><i><font size="3">$1</font></i></h5>');
    html = html.replace(/^####\s+([\s\S]*?)$/gm, '<h4 style="margin-bottom: 8px;"><font size="3">$1</font></h4>');
    html = html.replace(/^###\s+([\s\S]*?)$/gm, '<h3 style="margin-bottom: 8px;"><font size="4">$1</font></h3>');
    html = html.replace(/^##\s+([\s\S]*?)$/gm, '<h2 style="margin-bottom: 8px;"><font size="5">$1</font></h2>');
    html = html.replace(/^#\s+([\s\S]*?)$/gm, '<h1 style="margin-bottom: 10px;"><font size="6">$1</font></h1>');

    // Horizontal Rule (3 or more dashes/stars/underscores on a line)
    // Must be before bold/italic/lists to prevent interference
    html = html.replace(/^(\*{3,}|-{3,}|_{3,})$/gm, '<hr style="margin: 12px 0;"/>');

    // Bold and italic (order matters!)
    html = html.replace(/\*\*\*(.*?)\*\*\*/g, '<b><i>$1</i></b>');
    html = html.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>');
    html = html.replace(/\*(.*?)\*/g, '<i>$1</i>');
    html = html.replace(/___(.*?)___/g, '<b><i>$1</i></b>');
    html = html.replace(/__(.*?)__/g, '<b>$1</b>');
    html = html.replace(/_(.*?)_/g, '<i>$1</i>');

    // Strikethrough
    html = html.replace(/~~(.*?)~~/g, '<s>$1</s>');

    // Links
    html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');

    // Task Lists (must be before regular lists)
    // Match - [ ] or - [x] or - [X]
    html = html.replace(/^\s*[\*\-] \[([ xX])\] (.*?)$/gm, function(match, checked, content) {
        const checkbox = checked.toLowerCase() === 'x' ? '☑' : '☐';
        return `<li_task>${checkbox} ${content}</li_task>`;
    });

    // Lists - Differentiate UL and OL
    // Replace * - with <li_ul>
    html = html.replace(/^\s*[\*\-] (.*?)$/gm, '<li_ul>$1</li_ul>');
    // Replace 1. with <li_ol>
    html = html.replace(/^\s*\d+\. (.*?)$/gm, '<li_ol>$1</li_ol>');

    // Wrap consecutive list items and EXTRACT them to protect from newline processing
    // Unordered
    html = html.replace(/(<li_ul>[\s\S]*?<\/li_ul>\s*)+/g, function(match) {
        // Strip newlines inside the list block to avoid double spacing later
        const content = match.replace(/<\/?li_ul>/g, (tag) => tag.replace('li_ul', 'li')).replace(/\n/g, '');
        const block = `<ul style="margin: 8px 0;">${content}</ul>`;
        protectedBlocks.push(block);
        return `\x00PROTECTEDBLOCK${protectedIndex++}\x00\n`;
    });

    // Ordered
    html = html.replace(/(<li_ol>[\s\S]*?<\/li_ol>\s*)+/g, function(match) {
        const content = match.replace(/<\/?li_ol>/g, (tag) => tag.replace('li_ol', 'li')).replace(/\n/g, '');
        const block = `<ol style="margin: 8px 0;">${content}</ol>`;
        protectedBlocks.push(block);
        return `\x00PROTECTEDBLOCK${protectedIndex++}\x00\n`;
    });

    // Task Lists
    html = html.replace(/(<li_task>[\s\S]*?<\/li_task>\s*)+/g, function(match) {
        const content = match.replace(/<\/?li_task>/g, (tag) => tag.replace('li_task', 'li')).replace(/\n/g, '');
        const block = `<ul style="list-style-type: none; margin: 8px 0;">${content}</ul>`;
        protectedBlocks.push(block);
        return `\x00PROTECTEDBLOCK${protectedIndex++}\x00\n`;
    });

    // Blockquotes
    // Note: '>' is already escaped to '&gt;'
    html = html.replace(/^&gt; (.*?)$/gm, '<bq_line>$1</bq_line>');
    html = html.replace(/(<bq_line>[\s\S]*?<\/bq_line>\s*)+/g, function(match) {
        // Merge content, replacing closing/opening tags with BR
        // <bq_line>A</bq_line>\n<bq_line>B</bq_line> -> A<br/>B
        const inner = match.replace(/<\/bq_line>\s*<bq_line>/g, '<br/>')
                           .replace(/<bq_line>/g, '')
                           .replace(/<\/bq_line>/g, '')
                           .trim();
        // Use blockquote tag (supported by QML for indentation) and add styling
        const block = `<blockquote style="background-color: ${c.blockquoteBg}; border-left: 4px solid ${c.blockquoteBorder}; padding: 4px; margin: 8px 0;"><font color="#a0a0a0"><i>${inner}</i></font></blockquote>`;
        protectedBlocks.push(block);
        return `\x00PROTECTEDBLOCK${protectedIndex++}\x00\n`;
    });

    // Detect plain URLs and wrap them in anchor tags (but not inside existing <a> or markdown links)
    html = html.replace(/(^|[^"'>])((https?|file):\/\/[^\s<]+)/g, '$1<a href="$2">$2</a>');

    // Restore code blocks and inline code BEFORE line break processing
    // (We want newlines in code blocks to become <br> or handled by pre?)
    // Actually, QML Text <pre> handles \n correctly?
    // If we let \n become <br>, it might be double spacing in pre.
    // Let's protect code blocks too if we suspect issues, but previously it was fine.
    // Actually, let's keep code blocks as they were, handled before line breaks.
    html = html.replace(/\x00CODEBLOCK(\d+)\x00/g, (match, index) => {
        return codeBlocks[parseInt(index)];
    });

    html = html.replace(/\x00INLINECODE(\d+)\x00/g, (match, index) => {
        return inlineCode[parseInt(index)];
    });

    // Line breaks (after code blocks are restored)
    html = html.replace(/\n\n/g, '</p><p>');
    html = html.replace(/\n/g, '<br/>');

    // Wrap in paragraph tags if not already wrapped
    if (!html.startsWith('<') && !html.startsWith('\x00')) {
        html = '<p>' + html + '</p>';
    }

    // Restore PROTECTED blocks (Lists, Blockquotes) AFTER line break processing
    html = html.replace(/\x00PROTECTEDBLOCK(\d+)\x00/g, (match, index) => {
        return protectedBlocks[parseInt(index)];
    });

    // Clean up the final HTML
    // Remove <br/> tags immediately before block elements
    html = html.replace(/<br\/>\s*(<pre>)/g, '$1');
    html = html.replace(/<br\/>\s*(<ul[^>]*>)/g, '$1');
    html = html.replace(/<br\/>\s*(<ol[^>]*>)/g, '$1');
    html = html.replace(/<br\/>\s*(<blockquote[^>]*>)/g, '$1');
    html = html.replace(/<br\/>\s*(<table[^>]*>)/g, '$1');
    html = html.replace(/<br\/>\s*(<h[1-6][^>]*>)/g, '$1');

    // Remove empty paragraphs
    html = html.replace(/<p>\s*<\/p>/g, '');
    html = html.replace(/<p>\s*<br\/>\s*<\/p>/g, '');

    // Remove excessive line breaks
    html = html.replace(/(<br\/>){3,}/g, '<br/><br/>'); // Max 2 consecutive line breaks
    html = html.replace(/(<\/p>)\s*(<p>)/g, '$1$2'); // Remove whitespace between paragraphs

    // Remove leading/trailing whitespace
    html = html.trim();

    return html;
}
