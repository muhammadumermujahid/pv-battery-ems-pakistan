import asyncio
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(device_scale_factor=5, viewport={'width': 460, 'height': 300})
        await pg.set_content('<body style="margin:0;background:#fff">' + open('fig2.svg').read() + '</body>')
        await pg.locator('svg').screenshot(path='../img/fig2.png'); await b.close()
asyncio.run(main())
