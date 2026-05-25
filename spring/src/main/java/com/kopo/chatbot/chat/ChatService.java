package com.kopo.chatbot.chat;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class ChatService {

    @Autowired
    private RestTemplate restTemplate;

    private static final String FASTAPI_URL = "http://localhost:9999/predict";

    public ChatResponse ask(ChatRequest request) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<ChatRequest> entity = new HttpEntity<>(request, headers);
        return restTemplate.postForObject(FASTAPI_URL, entity, ChatResponse.class);
    }
}
