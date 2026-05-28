from fastapi import APIRouter
from fastapi.responses import Response

router = APIRouter(prefix="/reports", tags=["reports"])


@router.post("/pdf")
async def generate_pdf(payload: dict):
    return Response(content=b"PDF placeholder", media_type="application/pdf")


@router.post("/csv")
async def generate_csv(payload: dict):
    return Response(content=b"CSV placeholder", media_type="text/csv")


@router.post("/excel")
async def generate_excel(payload: dict):
    return Response(
        content=b"Excel placeholder", media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
