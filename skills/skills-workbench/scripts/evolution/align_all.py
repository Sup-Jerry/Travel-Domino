import os
import sys
import subprocess

def default_skills_root():
    # scripts/evolution/align_all.py -> skills-workbench -> skills
    return os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "..", "..")
    )

def align_all(skills_root):
    if not os.path.exists(skills_root):
        print(f"Error: {skills_root} not found")
        return

    stitch_script = os.path.join(os.path.dirname(__file__), "smart_stitch.py")
    
    count = 0
    for item in os.listdir(skills_root):
        skill_dir = os.path.join(skills_root, item)
        if not os.path.isdir(skill_dir):
            continue
            
        evolution_json = os.path.join(skill_dir, "evolution.json")
        if os.path.exists(evolution_json):
            print(f"Aligning {item}...")
            # Run the smart_stitch script for this skill
            subprocess.run([sys.executable, stitch_script, skill_dir])
            count += 1
            
    print(f"\nFinished. Aligned {count} skills.")

if __name__ == "__main__":
    skills_path = default_skills_root()
    if len(sys.argv) > 1:
        skills_path = os.path.abspath(sys.argv[1])
    align_all(skills_path)
