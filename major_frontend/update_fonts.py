import re

file_path = r'd:\Major 1\major_frontend\lib\screens\body_data\body_data.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Define the replacements as pairs of (regex_pattern, replacement_string)
# These patterns target specific button texts and labels that should be regular.

replacements = [
    # Buttons - General "Continue" buttons that should be regular
    (r"('Continue',\s+style:\s+TextStyle\([^)]+fontWeight:\s+)FontWeight\.w600", r"\1FontWeight.normal"),
    (r"('Continue',\s+style:\s+TextStyle\([^)]+fontWeight:\s+)FontWeight\.bold", r"\1FontWeight.normal"),
    
    # Specific buttons with different text
    (r"('Start Training',\s+style:\s+TextStyle\([^)]+fontWeight:\s+)FontWeight\.w600", r"\1FontWeight.normal"),
    
    # Ruler numbers that should be regular (Weight screen)
    (r"(fontSize:\s+isSelected\s+\?\s+22\s+:\s+18,\s+fontWeight:\s+)FontWeight\.bold", r"\1FontWeight.normal"),
    
    # Ruler numbers that should be regular (Height screen)
    (r"(fontSize:\s+24,\s+fontWeight:\s+)FontWeight\.bold", r"\1FontWeight.normal"),

    # Location screen section header "Add All Equipment..."
    (r"('Add All Equipment You have access to:',\s+style:\s+TextStyle\([^)]+fontWeight:\s+)FontWeight\.w600", r"\1FontWeight.normal"),

    # Back button text
    (r"('Back',\s+style:\s+TextStyle\([^)]+fontWeight:\s+)FontWeight\.normal", r"\1FontWeight.normal"), # Just to ensure we don't double up
]

new_content = content
for pattern, replacement in replacements:
    new_content = re.sub(pattern, replacement, new_content, flags=re.MULTILINE)

# Fixing the remaining specific ones detected in previous view_file
# Line 123
new_content = re.sub(r"(child:\s+const\s+Text\(\s+'Continue',\s+style:\s+TextStyle\(\s+fontSize:\s+16,\s+fontWeight:\s+)FontWeight\.w600", 
                     r"\1FontWeight.normal", new_content)

# Line 371
new_content = re.sub(r"(child:\s+const\s+Text\(\s+'Continue',[\s\w:\.\(\),]+fontWeight:\s+)FontWeight\.w600", 
                     r"\1FontWeight.normal", new_content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Font weights updated successfully.")
