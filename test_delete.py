import httpx
import asyncio

async def test():
    async with httpx.AsyncClient() as client:
        # Login first
        res = await client.post(
            'https://professor-os-production-65b2.up.railway.app/api/v1/auth/login',
            json={'email': 'admin@professoros.edu.pk', 'password': 'admin123'}
        )
        token = res.json()['access_token']
        headers = {'Authorization': f'Bearer {token}'}
        
        # Create assignment
        course_id = 28
        payload = {
            'title': 'Test Assignment',
            'description': 'Test',
            'type': 'text',
            'max_marks': 50,
            'deadline': '2025-12-31T23:59:59'
        }
        res = await client.post(
            f'https://professor-os-production-65b2.up.railway.app/api/v1/courses/{course_id}/assignments',
            json=payload,
            headers=headers
        )
        print(f'Create status: {res.status_code}')
        if res.status_code == 201:
            aid = res.json()['id']
            print(f'Created assignment {aid}')
            
            # Try to delete it
            res = await client.delete(
                f'https://professor-os-production-65b2.up.railway.app/api/v1/courses/{course_id}/assignments/{aid}',
                headers=headers
            )
            print(f'Delete status: {res.status_code}')
            print(f'Delete response: {res.text}')

asyncio.run(test())
