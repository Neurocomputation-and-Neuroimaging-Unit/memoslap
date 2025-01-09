# Automatic email reminder based on google calendar entries
The code can be used to automatically send reminder emails to participants when their appointment is upcoming.  

1) Create Google Calendar API
- Create a Google Cloud project and enable the API:
	1.	Go to the Google Cloud Console.
	2.	Create a new project.
	3.	Enable the Google Calendar API for the project.
	4.	Create OAuth 2.0 credentials:
	•	Type: Desktop App
	•	Download the credentials.json file.

- Allow certain users (e.g. your own email account) to access the app during testing:
	1.	Go to the Google Cloud Console.
	2.	Navigate to APIs & Services > OAuth consent screen.
	3.	Under “Test users,” add the email addresses of users who should have access.
	4.	Save the changes.

2) Adjust the script to your email account
  
3) Set a recurring execution of the batch script with Windows Scheduler
- Open Task Scheduler by searching for it in the Start menu.
- Click on "Create Basic Task..." in the Actions pane.
- Name your task and provide a description, then click "Next".
- Choose "Daily" and click "Next".
- Set the start date and time, then click "Next".
- Choose "Start a program" and click "Next".
- Click "Browse..." and select the run_apptReminder.bat file you created.
- Click "Next", then "Finish".
