# 📋 Detailed Feature Documentation

### 1. AI-Powered Triage & Severity Scoring
Using **Gemini 2.5 Flash**, the app automatically analyzes images of potholes, garbage, or broken lights. 
- **Auto-Dept:** Assigns the ticket to (e.g., Road Dept vs. Electricity).
- **Severity Index:** Calculates a priority score (Low/Medium/High) to help officials manage limited resources.

### 2. The Verification Loop (Computer Vision Audit)
To prevent "Ghost Resolutions" (where officials mark a task done without doing it):
- The contractor must upload a completion photo.
- **AI Audit:** The system compares the 'Before' and 'After' pixels. 
- **Approval:** The ticket is only closed if the AI detects the hazard is removed.

### 3. City Command Center (Admin Dashboard)
A Flutter Web/Desktop interface for Municipal Engineers:
- **Live Heatmaps:** See where clusters of issues are appearing.
- **Stat Cards:** Real-time tracking of 'Action Required' vs. 'AI Verified' fixes.
- **Department Filters:** Streamlined view for specific city workers.

### 4. SLA Breach Protocol (Escalation Engine)
*Architecture defined; module in final implementation phase.*
- **Automated RTI:** If a high-priority ticket is stale for >72h, the system generates a draft RTI application.
- **X (Twitter) Integration:** Auto-generates a post tagging the Ward Councillor and Commissioner to create public accountability.

### 5. Citizen Crowdfund Threat (PR Engine)
*Designed for local impact.*
- If the government fails to act within 30 days, the app unlocks a community funding progress bar. 
- **The Impact:** It acts as a "Public Shame" mechanism, forcing official action before citizens resort to private contractors.

### 6. Geotagged Accountability
- Every report is locked to its GPS coordinates. 
- Prevents duplicate reporting of the same pothole.
- Provides a "Citizen Map" to see live issues in their neighborhood.

### 7. Geospatial Deduplication Engine
To prevent "Report Spam" and administrative clutter, CivicLens includes an intelligent deduplication layer:
- **Proximity Logic:** When a user reports a hazard, the system scans a 20-meter radius for existing open tickets of the same category.
- **Vote Aggregation:** Instead of creating a duplicate ticket, the engine converts the new report into a "Community Upvote" on the original ticket.
- **Evidence Stacking:** The new photo is appended to the existing ticket as secondary evidence, giving officials multiple perspectives of the same issue without cluttering the dashboard.