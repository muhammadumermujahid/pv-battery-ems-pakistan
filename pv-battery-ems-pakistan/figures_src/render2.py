import asyncio
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch()
        for k,vw in (('fig0',940),('fig1',520)):
            pg=await b.new_page(device_scale_factor=4,viewport={'width':vw,'height':520})
            await pg.set_content('<body style="margin:0;background:#fff">'+open(k+'.svg').read()+'</body>')
            await pg.locator('svg').screenshot(path=f'../img/{k}_new.png'); await pg.close()
        await b.close()
asyncio.run(main())
