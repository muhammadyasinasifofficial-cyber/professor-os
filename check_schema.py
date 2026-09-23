import httpx
import asyncio

async def test():
    async with httpx.AsyncClient() as client:
        # Check OpenAPI schema to see available endpoints
        res = await client.get('https://professor-os-production-65b2.up.railway.app/openapi.json')
        if res.status_code == 200:
            data = res.json()
            paths = data.get('paths', {})
            
            # Look for assignment delete endpoints
            for path, methods in paths.items():
                if 'assignments' in path and 'delete' in methods:
                    print(f'Found DELETE: {path}')
        else:
            print(f'Could not fetch OpenAPI schema: {res.status_code}')

asyncio.run(test())
