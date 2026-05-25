# OpenSearch 개발 매뉴얼

## 1. 개요

OpenSearch를 벡터 데이터베이스로 활용하여 RAG(Retrieval-Augmented Generation) 챗봇을 구성한 개발 매뉴얼입니다.

---

## 2. 클러스터 정보

| 항목 | 값 |
|---|---|
| Host | 192.168.110.111 |
| Port | 9200 |
| 클러스터명 | opensearch-cluster |
| 버전 | OpenSearch 3.3.2 |
| SSL | 사용 (인증서 검증 비활성화) |
| 인증 | Basic Auth (admin / Eoiy961026!) |

---

## 3. 환경 설정 (.env)

```env
OPENSEARCH_HOST=192.168.110.111
OPENSEARCH_PORT=9200
OPENSEARCH_USER=admin
OPENSEARCH_PASSWORD=Eoiy961026!
OPENSEARCH_USE_SSL=true
OPENSEARCH_VERIFY_CERTS=false
OPENSEARCH_INDEX=my_vector_index
```

---

## 4. 연결 방법

```python
from opensearchpy import OpenSearch
import os
from dotenv import load_dotenv

load_dotenv()

client = OpenSearch(
    hosts=[{"host": os.getenv('OPENSEARCH_HOST'), "port": int(os.getenv('OPENSEARCH_PORT'))}],
    http_auth=(os.getenv('OPENSEARCH_USER'), os.getenv('OPENSEARCH_PASSWORD')),
    use_ssl=os.getenv('OPENSEARCH_USE_SSL').lower() == 'true',
    verify_certs=os.getenv('OPENSEARCH_VERIFY_CERTS').lower() == 'true',
    ssl_show_warn=False,
)

# 연결 확인
print(client.info()['cluster_name'])  # opensearch-cluster
print(client.indices.exists(index='my_vector_index'))
```

---

## 5. 인덱스 생성

벡터 검색을 위해 KNN(k-Nearest Neighbor) 인덱스를 생성합니다.
인덱스가 이미 존재하면 생성을 건너뜁니다.

```python
INDEX_NAME = 'my_vector_index'
EMBEDDING_DIM = 1024  # bge-m3 모델의 벡터 차원

if client.indices.exists(index=INDEX_NAME):
    print(f'인덱스 [{INDEX_NAME}] 이미 존재 - 생성 스킵')
else:
    client.indices.create(index=INDEX_NAME, body={
        'settings': {'index': {'knn': True}},
        'mappings': {'properties': {
            'embedding': {'type': 'knn_vector', 'dimension': EMBEDDING_DIM},
            'chunk_text': {'type': 'text'},
            'title': {'type': 'text'},
            'category': {'type': 'keyword'}
        }}
    })
    print(f'인덱스 [{INDEX_NAME}] 생성 완료')
```

### 필드 설명

| 필드 | 타입 | 설명 |
|---|---|---|
| embedding | knn_vector (dim=1024) | bge-m3 임베딩 벡터 |
| chunk_text | text | 청크 분할된 본문 텍스트 |
| title | text | 문서 제목 |
| category | keyword | 문서 카테고리 |

---

## 6. 데이터 전처리 및 청크 분할

```python
from langchain_text_splitters import RecursiveCharacterTextSplitter

CHUNK_SIZE = 600
CHUNK_OVERLAP = 100

text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=CHUNK_SIZE,
    chunk_overlap=CHUNK_OVERLAP,
    separators=["\n\n", "\n", ".", "!", "?", ",", " ", ""]
)

chunks = []
for item in data:
    full_text = f"""제목: {item['title']}
카테고리: {item['category']}
가격: {item['price']}원
설명: {item['description']}"""

    splits = text_splitter.split_text(full_text)
    for split in splits:
        chunks.append({
            "id": item['id'],
            "title": item['title'],
            "category": item['category'],
            "chunk_text": split,
        })
```

### 하이퍼파라미터 설명

| 파라미터 | 값 | 설명 |
|---|---|---|
| CHUNK_SIZE | 600 | 청크 최대 길이 (클수록 문맥 유지↑, 정밀도↓) |
| CHUNK_OVERLAP | 100 | 청크 간 겹침 길이 (클수록 문맥 단절 방지) |
| K_RETRIEVAL | 4 | 검색 시 반환할 문서 수 |

---

## 7. 임베딩 및 벡터 저장

```python
from langchain_community.embeddings import OllamaEmbeddings
from tqdm import tqdm

# bge-m3 임베딩 모델 초기화
embedder = OllamaEmbeddings(model='bge-m3')

# 벡터 저장
for chunk in tqdm(chunks):
    embedding = embedder.embed_query(chunk['chunk_text'])

    client.index(
        index=INDEX_NAME,
        body={
            "id": chunk['id'],
            "title": chunk['title'],
            "category": chunk['category'],
            "chunk_text": chunk['chunk_text'],
            "embedding": list(embedding),
        }
    )

# 인덱스 새로고침 및 저장 수 확인
client.indices.refresh(index=INDEX_NAME)
count = client.count(index=INDEX_NAME)['count']
print(f'저장된 벡터 수: {count}')
```

---

## 8. 벡터 검색 (KNN)

### 직접 검색 (opensearchpy)

```python
query = "카메라 성능이 좋은 스마트폰"
query_embedding = embedder.embed_query(query)

results = client.search(
    index=INDEX_NAME,
    body={
        "query": {
            "knn": {
                "embedding": {
                    "vector": query_embedding,
                    "k": 4
                }
            }
        }
    }
)

for hit in results['hits']['hits']:
    print(hit['_source']['title'])
    print(hit['_source']['chunk_text'][:100])
```

### LangChain Retriever 방식

```python
from langchain_community.vectorstores import OpenSearchVectorSearch

OPENSEARCH_HOST = os.getenv('OPENSEARCH_HOST')
OPENSEARCH_PORT = os.getenv('OPENSEARCH_PORT')

vectorstore = OpenSearchVectorSearch(
    opensearch_url=f"https://{OPENSEARCH_HOST}:{OPENSEARCH_PORT}",
    index_name=INDEX_NAME,
    embedding_function=embedder,
    http_auth=(os.getenv('OPENSEARCH_USER'), os.getenv('OPENSEARCH_PASSWORD')),
    vector_field="embedding",
    text_field="chunk_text",
    use_ssl=True,
    verify_certs=False,
    ssl_show_warn=False,
)

retriever = vectorstore.as_retriever(
    search_kwargs={
        "k": 4,
        "vector_field": "embedding",
        "text_field": "chunk_text"
    }
)
```

---

## 9. RAG 체인 구성

```python
from langchain_community.llms import Ollama
from langchain_core.prompts import PromptTemplate
from langchain_core.runnables import RunnablePassthrough, RunnableParallel
from langchain_core.output_parsers import StrOutputParser

# LLM 초기화
llm = Ollama(model='gemma4:e2b', temperature=0.2)

# 프롬프트 템플릿
PROMPT_TEMPLATE = """
다음 컨텍스트를 우선적으로 참고하여 한국어로 간결하고 정확하게 답변하세요.
컨텍스트에 없는 내용은 당신이 알고 있는 지식으로 답변하세요.

컨텍스트:
{context}

질문: {question}
답변:
"""

prompt_template = PromptTemplate(
    template=PROMPT_TEMPLATE,
    input_variables=["context", "question"]
)

def format_docs(docs):
    formatted = []
    for i, doc in enumerate(docs, 1):
        title = doc.metadata.get('title', '')
        category = doc.metadata.get('category', '')
        formatted.append(f"[출처 {i}] 제목: {title} | 카테고리: {category}\n{doc.page_content}")
    return "\n\n".join(formatted)

# RAG 체인
retrieval_chain = RunnableParallel({
    "context": retriever | format_docs,
    "question": RunnablePassthrough(),
    "source_documents": retriever
})

answer_chain = (
    {"context": lambda x: x["context"], "question": lambda x: x["question"]}
    | prompt_template
    | llm
    | StrOutputParser()
)

rag_chain = retrieval_chain | RunnablePassthrough.assign(answer=answer_chain)
```

---

## 10. FastAPI 연동 (/predict 엔드포인트)

Spring에서 호출하는 엔드포인트입니다.

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import nest_asyncio

app = FastAPI(title="ML API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

class InDataset(BaseModel):
    question: str

@app.post("/predict", status_code=200)
async def predict(x: InDataset):
    response = rag_chain.invoke(x.question)
    return {
        "prediction": response["answer"],
        "references": [
            {
                "title": doc.metadata.get("title", ""),
                "category": doc.metadata.get("category", ""),
                "content": doc.page_content[:200]
            }
            for doc in response["source_documents"]
        ]
    }

nest_asyncio.apply()
uvicorn.run(app, host="0.0.0.0", port=9999, log_level="info")
```

### 응답 JSON 형식

```json
{
  "prediction": "AI 답변 텍스트",
  "references": [
    {
      "title": "문서 제목",
      "category": "카테고리",
      "content": "내용 일부 (200자)"
    }
  ]
}
```

---

## 11. 전체 시스템 아키텍처

```
사용자 (브라우저)
    ↓ HTTP GET  http://localhost:8181/exam/chatview
JSP (chat.jsp)
    ↓ fetch POST  /chat  { question: "..." }
Spring Controller (ChatController)
    ↓ RestTemplate POST  http://localhost:9999/predict
FastAPI (/predict)
    ↓ embed 질문 → KNN 검색
OpenSearch (my_vector_index, 벡터 30개)
    ↓ Top-4 문서 반환
FastAPI → Ollama (gemma4:e2b) → 답변 생성
    ↓ { prediction, references }
Spring → JSP → 사용자
```

---

## 12. 실행 순서

1. **Ollama 실행**: `ollama serve`
2. **FastAPI 서버**: Jupyter에서 노트북 셀 순서대로 실행 → uvicorn 포트 9999
3. **Spring/Tomcat**: STS에서 Run on Server → 포트 8181
4. **접속**: `http://localhost:8181/exam/chatview`

---

## 13. 주요 모델 정보

| 항목 | 값 |
|---|---|
| 임베딩 모델 | bge-m3 (벡터 차원: 1024) |
| LLM | gemma4:e2b (Ollama) |
| Temperature | 0.2 |
| 검색 방식 | KNN (코사인 유사도) |
