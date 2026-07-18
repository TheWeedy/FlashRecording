const String liveMarkdownCaptureScript = r'''
(() => {
  const cleanup = (root) => {
    root.querySelectorAll('script, style, noscript, nav, footer, header, iframe, form').forEach((node) => node.remove());
    root.querySelectorAll('[hidden], [aria-hidden="true"], .advert, .ad, .ads, .recommend, .related, .comment, .share, .toolbar').forEach((node) => node.remove());
    root.querySelectorAll('img').forEach((img) => {
      const lazySrc = img.getAttribute('data-src') || img.getAttribute('data-original') || img.getAttribute('data-url');
      if (lazySrc && !img.getAttribute('src')) {
        img.setAttribute('src', lazySrc);
      }
    });
  };

  const selectors = [
    '#js_content',
    '.rich_media_content',
    'article',
    'main',
    '[role="main"]',
    '.article',
    '.content',
    '.post-content',
    '.entry-content',
    '.markdown-body'
  ];
  let source = null;
  for (const selector of selectors) {
    const candidate = document.querySelector(selector);
    if (candidate && candidate.innerText && candidate.innerText.trim().length > 40) {
      source = candidate;
      break;
    }
  }
  if (!source) {
    source = document.body || document.documentElement;
  }

  const clone = source.cloneNode(true);
  cleanup(clone);
  const wechatTitle = document.querySelector('.rich_media_title')?.innerText?.trim();
  const title = wechatTitle || document.title || location.hostname;
  return JSON.stringify({
    title,
    url: location.href,
    html: clone.outerHTML,
    textLength: (clone.innerText || '').trim().length
  });
})()
''';
