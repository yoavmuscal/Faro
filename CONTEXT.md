# Faro: Complete Team Strategy & Build Plan
YHACK 2026
Mert · Sam · Yoav
Binghamton University · March 28–29, 2026 · Yale University

**One sentence:** A business owner describes their company in plain English, and an AI agent autonomously determines their insurance needs, builds a carrier-ready submission packet, and explains their options — in under 2 minutes.

---

## 1. The Idea
### What we are building
An AI-native commercial insurance agent that lives on iOS and iPadOS as a beautiful native app. A small business owner opens it, describes their business in plain English, and the agent autonomously reasons through their risk profile, determines what coverage they need, generates a carrier-ready submission packet, and explains everything in language a real person actually understands.

What Harper’s human brokers spend 5–7 days doing manually, our agent does in under 2 minutes.

### Why this specifically
Harper is a YC-backed AI-native commercial insurance brokerage that raised $47M in early 2026. Their stated mission is to automate the entire broker workflow for small and mid-sized businesses. Their CEO has publicly said he wants Harper to become “the focal point for all risk, compliance, and back office” for entrepreneurs. We are building the client-facing layer of that vision. Not a chatbot. Not a form. A full agentic pipeline that thinks like a broker.

### The competitive angle
Every team at this hackathon will build a React web app. We are building a native iOS and iPadOS app in SwiftUI. Judges can hold it. That is a physical differentiator. We are also thinking further down the product roadmap: proactive monitoring (widget).

## 2. Prize Strategy
We build one genuinely excellent product and make sure it naturally qualifies for multiple tracks. 
*   **Harper — Personal AI Agent 1st:** Core project. $2,000 + Meta Quest 3s.
*   **Built with Zed:** Code in the Zed editor.
*   **ElevenLabs (MLH):** Voice reads coverage summary.
*   **MongoDB (MLH):** Use MongoDB Atlas for session storage.
*   **Auth0 (MLH):** Login screen (if time permits).
*   **Best UI/UX:** Polish the SwiftUI frontend.
*   **Grand Prize:** $4,000 / $2,000 / $1,000.

## 3. Tech Stack
**Frontend (Mert):**
*   SwiftUI: Primary framework.
*   WidgetKit: Home screen widget showing live coverage status.
*   URLSession + WebSocket: Streams agent step updates.
*   AVFoundation: Plays ElevenLabs voice natively.
*   Auth0 iOS SDK: Authentication.
*   PDFKit: Renders and shares the submission packet PDF.

**Backend (Sam + Yoav):**
*   FastAPI (Python): Main API server.
*   AWS Lambda / API Gateway: Serverless runner for the API.
*   LangGraph: Orchestrates the 4-step agent pipeline.
*   K2 Think V2 (MBZUAI): Primary reasoning model for steps 1 & 2.
*   MongoDB Atlas: Session storage.
*   ElevenLabs API: Voice summary synthesis.
*   Auth0: Backend token verification.

## 4. The Agent Pipeline (LangGraph)
Four sequential steps orchestrated by LangGraph. K2 Think V2 powers the reasoning.
*   **Step 1 — Risk Profiler:** Output structured risk profile JSON from raw text.
*   **Step 2 — Coverage Mapper:** Output required/recommended/projected policies with scaling triggers.
*   **Step 3 — Submission Builder:** Generates a structured carrier submission packet.
*   **Step 4 — Explainer:** Rewrites coverage recommendations in plain English. Sent to ElevenLabs.

## 5. API Contract
*   `POST /intake`: Kick off pipeline, returns `session_id`.
*   `WebSocket /ws/{session_id}`: Streams agent step updates (`risk_profiler`, `coverage_mapper`, etc.)
*   `GET /results/{session_id}`: Returns the full structured output (coverage options, pdf url, audio url).
*   `GET /status/{session_id}`: Polled by WidgetKit for coverage health.

## 6. iOS App — The Three Screens
*   **Screen 1 — Onboarding flow:** Conversational, one-question-at-a-time.
*   **Screen 2 — Live agent tracker:** Vertical timeline. Cards slide in from the bottom via WebSocket. Say nothing to the judges; let them watch the agent think.
*   **Screen 3 — Coverage dashboard:** Three swipeable cards. Button for "Hear your summary" (ElevenLabs) and "Export submission packet" (PDF generation).
*   **Widget:** Small/medium/large variants showing coverage status pulled from `/status`.

## 7. Dependency-Driven Timeline & Implementation Steps

**Code freeze is 8 AM Sunday. No exceptions. Auth0 has been officially cut to prioritize core AI and native iOS features.**

### Pre-Hackathon: Infrastructure Setup (Friday Night)
*Goal: Walk into the venue tomorrow ready to write business logic, not config files.*
*   **Repo & Cloud:** Initialize the shared GitHub repository. Provision a free MongoDB Atlas cluster and whitelist 0.0.0.0/0 for hackathon access.
*   **Keys & Endpoints:** Generate and test API keys for K2 Think V2, ElevenLabs, and any fallback LLMs (Claude/GPT-4).
*   **Boilerplate:** Initialize the blank Xcode (SwiftUI) project. Deploy a basic "Hello World" FastAPI endpoint to AWS Lambda / API Gateway to ensure routing works.

### Phase 1: The Mock Contract (Sat 11:00 AM — 12:00 PM)
*Goal: Unblock the frontend completely so UI development can happen in parallel with AI prompt engineering.*
*   **Backend — Dummy API:** Spin up a local FastAPI server. Build the four core endpoints (`POST /intake`, `WS /ws/{session_id}`, `GET /results/{session_id}`, `GET /status/{session_id}`). Hardcode JSON responses exactly matching the agreed-upon API contract, including the new "category": "projected" fields and trigger_event strings.
*   **Frontend — Architecture & Models:** Create the 3-screen navigation shell in SwiftUI. Define the Swift Structs (Codable) to parse the mock JSON data. Connect the app to the dummy local server and verify data decodes correctly.

### Phase 2: Independent Core Build (Sat 12:00 PM — 5:00 PM)
*Goal: Build the real engines in isolation.*
*   **Backend — LangGraph & AI Pipeline:** Define the LangGraph state schema (passing the business profile and JSON accumulated at each step).
    *   **Step 1 (Risk Profiler):** Write the K2 prompt to extract industry risks.
    *   **Step 2 (Coverage Mapper):** Write the "Demo-Driven Prompt" instructing K2 to categorize policies as required, recommended, or projected (strictly based on scaling/headcount triggers).
    *   **Step 3 & 4 (Builder & Explainer):** Format the JSON output and generate the plain-English summary.
*   **Backend — Database & Audio:** Connect FastAPI to MongoDB Atlas. Save the session state on `POST /intake` and update it as the graph runs. Connect the ElevenLabs API to Step 4. Generate the audio file, store it (or return a presigned/direct URL), and pass that URL into the final JSON response.
*   **Frontend — Core UI/UX:**
    *   **Screen 1 (Onboarding):** Build the conversational text inputs with smooth SwiftUI transition animations.
    *   **Screen 3 (Dashboard):** Build the coverage cards. Implement the visual hierarchy: Red (Required), Amber (Recommended), and a distinct Purple/Dashed style for Projected, displaying the trigger_event text.
    *   Hook up AVFoundation to play the mock ElevenLabs audio URL when the "Hear Summary" button is tapped.

### Phase 3: The Integration Crucible (Sat 5:00 PM — 9:00 PM)
*Goal: Connect the real brain to the real face. This is where the highest risk of failure lives.*
*   **Backend — WebSocket Streaming:** Implement WebSocket support in FastAPI. As the LangGraph transitions between nodes (Steps 1 through 4), push status JSON messages (`"status": "running" | "complete"`) to the active WebSocket connection.
*   **Frontend — Live Agent Tracker (Screen 2):** Implement URLSession WebSocket logic in Swift. Bind incoming WebSocket messages to SwiftUI `@Published` variables. Build the UI where step cards slide in from the bottom automatically as the state changes.
*   **Full Stack Integration:** Swap the dummy endpoints for the live FastAPI endpoints. Send a real prompt from the iOS simulator and ensure it traverses the entire graph and updates the UI in real-time. Fix all CORS/JSON serialization mismatches here.

### Phase 4: Native Magic & Edge Cases (Sat 9:00 PM — 2:00 AM)
*Goal: Win the hackathon with physical differentiators and bulletproof reliability.*
*   **Backend — The Latency Fallback:** Wrap the K2 API calls in a strict timeout function (e.g., 8 seconds). If K2 times out or throws a 500 error, automatically route the exact same prompt to the Claude/GPT-4 API key so the pipeline does not stall during judging.
*   **Frontend — PDF Export:** Use PDFKit to draw a clean, formatted PDF document natively using the `GET /results` JSON data. Connect the generated PDF to a `UIActivityViewController` to trigger the native iOS Share Sheet (allowing Airdrop/email).
*   **Frontend — WidgetKit:** Build a simple iOS Home Screen widget. Have it poll the `GET /status/{session_id}` endpoint (or read from UserDefaults via an App Group) to display a simple Green/Amber/Red health indicator.

### Phase 5: Buffer, Triage, & Devpost (Sun 2:00 AM — 8:00 AM)
*Goal: Protect the demo at all costs.*
*   **Stress Test:** Run the "New Jersey Daycare" demo script end-to-end 10 times.
*   **Triage:** If the PDF looks terrible, drop it and just show the dashboard. If the WebSocket drops out, mock the loading screen timing. Do not write new features.
*   **Devpost:** Draft the Devpost submission focusing heavily on the product vision, the K2 reasoning, and the "Projected" coverage feature.
*   **8:00 AM:** Hard Code Freeze. Practice the 90-second script out loud.

## 8. The Demo Script (90 seconds)
1.  **The hook (10s):** "Getting commercial insurance takes a broker 5-7 days. We do it in 90 seconds." (Hand device to judge)
2.  **The intake (15s):** Let them type a sample prompt (e.g., "NJ Daycare 12 employees $800k revenue").
3.  **The agent working (30s):** Silence. Let them watch the websocket timeline.
4.  **The output (20s):** Play the ElevenLabs audio. Tap export to show the native iOS PDF share sheet.
5.  **The close (15s):** "Small business owners run their lives on phones. We automated the workflow natively."

## 9. Known Attacks and Counters
*   *Fabricated widget data?* "We built the client and reasoning layer; the carrier integration is just mock data out of scope."
*   *Why native Swift?* "Physical differentiator. Share sheet and widgets don't exist in web wrappers."
*   *K2 Latency?* "We have a fallback to Claude/GPT-4 if >8s."
*   *Not defensible?* "The moat is the risk reasoning specific to domains, which gets better over time. Code is replicable, accumulated logic isn't."


