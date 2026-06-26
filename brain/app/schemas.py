from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class AssistantAction(BaseModel):
    id: str = Field(default_factory=lambda: "brain_action")
    type: str
    payload: Dict[str, Any] = Field(default_factory=dict)


class StructuredResult(BaseModel):
    id: str
    rank: Optional[int] = None
    name: str
    url: Optional[str] = None
    price: Optional[str] = None
    reason: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)


class MemoryUpdate(BaseModel):
    text: str
    metadata: Dict[str, Any] = Field(default_factory=dict)


class ConfirmationRequest(BaseModel):
    id: str = "brain_confirmation"
    risk: str
    title: str
    description: str
    action: AssistantAction
    requiresTypedConfirmation: bool = False


class ResponseMetadata(BaseModel):
    route: Optional[str] = None
    provider: Optional[str] = None
    model: Optional[str] = None
    usedMemory: bool = False
    usedWeb: bool = False
    usedScreenContext: bool = False
    contextAvailable: bool = False
    warnings: List[str] = Field(default_factory=list)
    webSearchMode: Optional[str] = None
    ttsEngine: Optional[str] = None
    mood: Optional[str] = None
    actionCount: Optional[int] = None


class StructuredResponse(BaseModel):
    answer: str
    speak: str
    results: List[StructuredResult] = Field(default_factory=list)
    actions: List[AssistantAction] = Field(default_factory=list)
    memoryUpdates: List[MemoryUpdate] = Field(default_factory=list)
    requiresConfirmation: bool = False
    confirmation: Optional[ConfirmationRequest] = None
    modelUsed: Optional[str] = None
    metadata: ResponseMetadata = Field(default_factory=ResponseMetadata)


class ChatRequest(BaseModel):
    message: str
    conversationId: str
    context: Optional[Dict[str, Any]] = None
    session: Dict[str, Any] = Field(default_factory=dict)
    mode: str = "normal"
    # Intent + screen-context need are decided on the Swift side (single source
    # of truth). When present the brain trusts them instead of re-deriving its
    # own copy of the keyword/phrase tables.
    intent: Optional[str] = None
    requiresScreenContext: Optional[bool] = None


class MemoryAddRequest(BaseModel):
    text: str
    metadata: Dict[str, Any] = Field(default_factory=dict)


class MemorySearchRequest(BaseModel):
    query: str
    limit: int = 8


class MemoryEditRequest(BaseModel):
    id: str
    text: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)


class WebSearchRequest(BaseModel):
    query: str
    limit: int = 5


class FileIndexControlRequest(BaseModel):
    folders: Optional[List[str]] = None
    exclusions: Optional[List[str]] = None


class FileSearchRequest(BaseModel):
    query: str = ""
    limit: int = 8
    folders: Optional[List[str]] = None
    extensions: Optional[List[str]] = None
    modifiedAfter: Optional[datetime] = None
    modifiedBefore: Optional[datetime] = None
    createdAfter: Optional[datetime] = None
    createdBefore: Optional[datetime] = None


class FileReadRequest(BaseModel):
    id: Optional[str] = None
    path: Optional[str] = None
    maxChars: int = 24000


class FileSummarizeRequest(BaseModel):
    id: Optional[str] = None
    path: Optional[str] = None
    maxChars: int = 8000


class TTSRequest(BaseModel):
    text: str
    engine: str = "kokoro"
    voice: str = "af_heart"
    speed: float = 1.0
    referenceAudioPath: Optional[str] = None
    exaggeration: Optional[float] = None
    cfgWeight: Optional[float] = None
    stylePreset: Optional[str] = None
