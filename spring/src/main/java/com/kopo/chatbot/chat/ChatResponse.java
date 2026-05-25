package com.kopo.chatbot.chat;

import java.util.List;

public class ChatResponse {
    private String prediction;
    private List<ReferenceDto> references;

    public String getPrediction() { return prediction; }
    public void setPrediction(String prediction) { this.prediction = prediction; }

    public List<ReferenceDto> getReferences() { return references; }
    public void setReferences(List<ReferenceDto> references) { this.references = references; }
}
