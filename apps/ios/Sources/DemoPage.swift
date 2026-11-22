enum DemoPage {
    static let html = """
    <!doctype html>
    <html lang="en">
    <head><meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
      body { font: 18px -apple-system, sans-serif; background:#f3f5ff; color:#18213b;
             padding:18px; margin:0 }
      button { font:inherit; padding:16px 24px; background:#3458c8; color:white;
               border:0; border-radius:12px }
      article { margin:16px 0; padding:30px; background:white; border-radius:14px }
    </style></head>
    <body>
      <h2>LoopMate offline demo</h2>
      <p>Choose Tap, pick the button and start to repeat clicks.</p>
      <button onclick="document.getElementById('count').textContent =
        +document.getElementById('count').textContent + 1">Tap me</button>
      <p>Button clicks: <b id="count">0</b></p>
      <p>Choose Swipe up to scroll this page repeatedly.</p>
      <article>Section 1</article><article>Section 2</article>
      <article>Section 3</article><article>Section 4</article>
      <article>Section 5</article><article>Section 6</article>
      <article>Section 7</article><article>Section 8</article>
    </body></html>
    """
}
