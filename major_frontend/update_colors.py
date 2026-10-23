import re

file_path = r'd:\Major 1\major_frontend\lib\screens\body_data\body_data.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Define the replacements
replacements = [
    # Background color
    (r'0xFF1A1A1A', '0xFF1B1B1B'),
    
    # Primary button and accents
    (r'0xFF8B5CF6', '0xFF8A2BE2'),
    
    # Selection and softer colors
    (r'0xFFC0A9F6', '0xFFB497FF'), # Gender/Age/Weight/Height
    (r'0xFFB794F6', '0xFFB497FF'), # FocusArea/TrainingPlan
    (r'0xFFB2A0FF', '0xFFB497FF'), # TrainingLevel
]

new_content = content
for old, new in replacements:
    new_content = new_content.replace(old, new)

# Also check for any common variations that might be there
# (Not strictly necessary if I'm sure of the values, but safer)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Colors updated successfully in body_data.dart.")
