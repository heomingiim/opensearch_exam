<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>RAG 챗봇</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Malgun Gothic', sans-serif; background: #f0f2f5; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
  .chat-container { width: 700px; background: #fff; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); display: flex; flex-direction: column; height: 80vh; }
  .chat-header { background: #1976d2; color: #fff; padding: 16px 20px; border-radius: 12px 12px 0 0; font-size: 18px; font-weight: bold; }
  .chat-messages { flex: 1; overflow-y: auto; padding: 20px; display: flex; flex-direction: column; gap: 12px; }
  .message { max-width: 80%; padding: 10px 14px; border-radius: 10px; line-height: 1.5; word-break: break-word; white-space: pre-wrap; }
  .message.user { align-self: flex-end; background: #1976d2; color: #fff; border-bottom-right-radius: 2px; }
  .message.bot { align-self: flex-start; background: #f1f3f4; color: #333; border-bottom-left-radius: 2px; }
  .references { font-size: 12px; color: #666; margin-top: 4px; padding: 6px 10px; background: #e8f0fe; border-radius: 6px; border-left: 3px solid #1976d2; align-self: flex-start; max-width: 80%; }
  .references strong { color: #1976d2; }
  .chat-input { display: flex; padding: 12px; border-top: 1px solid #e0e0e0; gap: 8px; }
  .chat-input input { flex: 1; padding: 10px 14px; border: 1px solid #ddd; border-radius: 20px; font-size: 14px; outline: none; }
  .chat-input input:focus { border-color: #1976d2; }
  .chat-input button { padding: 10px 20px; background: #1976d2; color: #fff; border: none; border-radius: 20px; cursor: pointer; font-size: 14px; }
  .chat-input button:hover { background: #1565c0; }
  .chat-input button:disabled { background: #aaa; cursor: not-allowed; }
  .loading { align-self: flex-start; color: #999; font-size: 13px; padding: 8px 14px; }
</style>
</head>
<body>
<div class="chat-container">
  <div class="chat-header">RAG 챗봇 (OpenSearch + Ollama)</div>
  <div class="chat-messages" id="messages">
    <div class="message bot">안녕하세요! 궁금한 점을 질문해주세요.</div>
  </div>
  <div class="chat-input">
    <input type="text" id="questionInput" placeholder="질문을 입력하세요..." />
    <button id="sendBtn" onclick="sendMessage()">전송</button>
  </div>
</div>

<script>
  const input = document.getElementById('questionInput');
  const sendBtn = document.getElementById('sendBtn');
  const messages = document.getElementById('messages');

  input.addEventListener('keydown', function(e) {
    if (e.key === 'Enter') sendMessage();
  });

  function appendMessage(text, type) {
    const div = document.createElement('div');
    div.className = 'message ' + type;
    div.innerText = text;
    messages.appendChild(div);
    messages.scrollTop = messages.scrollHeight;
  }

  function appendReferences(refs) {
    if (!refs || refs.length === 0) return;
    const div = document.createElement('div');
    div.className = 'references';
    let html = '<strong>참조 문서:</strong><br>';
    refs.forEach(function(ref, i) {
      html += (i + 1) + '. [' + ref.category + '] ' + ref.title + '<br>';
    });
    div.innerHTML = html;
    messages.appendChild(div);
    messages.scrollTop = messages.scrollHeight;
  }

  function sendMessage() {
    const question = input.value.trim();
    if (!question) return;

    appendMessage(question, 'user');
    input.value = '';
    sendBtn.disabled = true;

    const loading = document.createElement('div');
    loading.className = 'loading';
    loading.innerText = '답변 생성 중...';
    messages.appendChild(loading);
    messages.scrollTop = messages.scrollHeight;

    fetch('${pageContext.request.contextPath}/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ question: question })
    })
    .then(function(res) { return res.json(); })
    .then(function(data) {
      messages.removeChild(loading);
      appendMessage(data.prediction, 'bot');
      appendReferences(data.references);
    })
    .catch(function(err) {
      messages.removeChild(loading);
      appendMessage('오류가 발생했습니다. FastAPI 서버 상태를 확인해주세요.', 'bot');
      console.error(err);
    })
    .finally(function() {
      sendBtn.disabled = false;
      input.focus();
    });
  }
</script>
</body>
</html>
