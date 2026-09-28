import os, json
from typing import Any
from azure.identity import DefaultAzureCredential
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from openai import AzureOpenAI

class IncidentAgent:
    """Read-only, evidence-grounded incident analyst."""
    def __init__(self):
        credential = DefaultAzureCredential()
        self.credential = credential
        self.search = SearchClient(
            endpoint=os.environ["AZURE_SEARCH_ENDPOINT"],
            index_name=os.environ["AZURE_SEARCH_INDEX"],
            credential=credential,
        )
        self.client = AzureOpenAI(
            azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
            api_version=os.getenv("AZURE_OPENAI_API_VERSION", "2024-10-21"),
            azure_ad_token_provider=lambda: credential.get_token("https://cognitiveservices.azure.com/.default").token,
        )
        self.chat_deployment = os.environ["AZURE_OPENAI_CHAT_DEPLOYMENT"]
        self.embedding_deployment = os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT", "embedding")

    def _embed(self, text: str):
        return self.client.embeddings.create(model=self.embedding_deployment, input=text).data[0].embedding

    def retrieve_runbooks(self, query: str, top_k: int = 5) -> list[dict[str, Any]]:
        vector = self._embed(query)
        results = self.search.search(
            search_text=query,
            vector_queries=[VectorizedQuery(vector=vector, k_nearest_neighbors=top_k, fields="contentVector")],
            top=top_k,
            select=["title", "content", "source"],
        )
        return [{"title": r.get("title"), "content": r.get("content"), "source": r.get("source")} for r in results]

    def analyze(self, incident: dict[str, Any]) -> dict[str, Any]:
        query = f"{incident.get('title','')} {incident.get('symptoms','')} {incident.get('service','')}"
        docs = self.retrieve_runbooks(query)
        context = "\n\n".join(f"SOURCE: {d['source']}\n{d['content']}" for d in docs)
        prompt = f"""Analyze this cloud incident using ONLY the evidence below. If evidence is insufficient, say so. Never invent telemetry.\n\nINCIDENT:\n{json.dumps(incident, indent=2)}\n\nRETRIEVED RUNBOOKS:\n{context}\n\nReturn JSON with summary, evidence, probable_cause, recommended_action, confidence, requires_human_approval."""
        response = self.client.chat.completions.create(
            model=self.chat_deployment,
            temperature=0,
            messages=[
                {"role": "system", "content": "You are a cautious SRE incident analyst. Ground every claim in evidence and cite runbook sources by filename."},
                {"role": "user", "content": prompt},
            ],
        )
        return {"analysis": response.choices[0].message.content, "sources": docs}
