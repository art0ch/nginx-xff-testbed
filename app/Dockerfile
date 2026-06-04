FROM python:3.11-slim

RUN useradd -m appuser

WORKDIR /app

COPY --chown=appuser:appuser server.py .

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=5s --timeout=10s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/')" || exit 1

CMD [ "python", "server.py", "8000" ]