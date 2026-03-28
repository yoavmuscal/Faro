import asyncio
import uuid
import json
from main import _run_pipeline_task
import database as db

async def run_test():
    print("Initializing test run...")
    session_id = str(uuid.uuid4())
    intake_data = {
        "business_name": "Sunny Days Daycare",
        "description": "A local daycare facility looking after 30 children.",
        "employee_count": 5,
        "state": "NJ",
        "annual_revenue": 250000
    }
    
    print(f"Session ID: {session_id}")
    print("Testing LangGraph Pipeline with Gemini Integration...")
    print("(Waiting on Gemini and MongoDB. This may take ~15 seconds...)")
    
    try:
        await _run_pipeline_task(session_id, intake_data)
        
        # Fetch the results from Mongo
        session = await db.get_session(session_id)
        if not session:
            print("\nError: No session found in MongoDB. Pipeline may have failed.")
            return

        print("\n--- TEST COMPLETE ---")
        if session.get("pipeline_status") == "error":
            print(f"Pipeline Pipeline Error: {session.get('error')}")
            return

        print("\nCoverage Options Generated:")
        print(json.dumps(session.get("coverage_requirements", []), indent=2))
        print("\nPlain English Summary:")
        print(session.get("plain_english_summary", "None"))
    except Exception as e:
        print(f"\nTest failed: {e}")
        print("Ensure your MONGODB_URI and GEMINI_API_KEY are real and properly configured in backend/.env!")
    finally:
        await db.close()

if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()
    asyncio.run(run_test())
