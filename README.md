dumptruck
=========

Tool to help manage postgres backups / restores using user built profiles for common tasks.
Allows you to quickly backup and restore without having to lookup filenames for the most recent
timestamp, and backup/restore specific tables quickly.

###Setup

1. Rename the dumptruck.sample to dumptruck.yml
2. Replace any of the profile items flanked with the *** to your specific setup.
3. Create a folder where you plan to store you database dumps. i.e /Users/me/Desktop/dumptruck-dumps

###Usage Examples

**Execute a database backup using the profile named ey**

`ruby dumptruck.rb -b -p ey`

**Same as above, but is taking advantage of the default: "true" entry in the config file**

`ruby dumptruck.rb -b`

**Restore a database using the ey profile**
`ruby dumptruck.rb -r -p ey`

**Again, assuming the default entry was used**

`ruby dumpturck.rb -r`

### Config
At the top of the config file are a few constants that you can use for common paths and options
you'll want in all profiles.

You can create as many profiles as you'd like.  You'll want to add:

`default: "true"`

to whatever profile you use the most.

The tables section is where you define which tables you want to backup / restore
You can choose by whitelist or blacklist depending on the task at hand.
Leaving the tables section blank will do all tables.

This will backup / restore only the mentioned tables:
```
tables:
  style: "whitelist"
  names: "forecasts, forecast_years, budgets, forecast_audit_logs"
```

This will backup / restore all tables but the forecasts table.
```
tables:
  style: "blacklist"
  names: "forecasts"
```


The filename for the restore section has some extra possibilities.

```
restore:
  filename:
```

This takes either the name of the file you'd like to restore (just the name no path)
or it has some special options.

'ey' - This will search the location you defined for your output_path for database dumps in the format used by
engineyard.  So if you frequently backup your database and put in a folder you can enter 'ey' for the
filename in your config and dumptruck will automatically restore the latest dump file.

'auto' - Auto will look for any backup files in your output_path that were created using the current profile.
example if you have a profile named 'users' that just backs up the user table and you've dont that 10 times today, run:

`ruby dumptruck.rb -r -p users`

And the newest backup will be loaded for you.  You don't need to know the name of the file!

If users is your default profile then you could just do:

`ruby dumptruck.rb -r`

### Future

* You currently cannot provide a user / host / connection info to backup a database
* The -f option as in  dumptruck.rb -f <some dump file> isn't implmented
* There isn't much validation on the command line args
* Need to enforce that you shouldn't use the -T or -t in the options section, but instead use the configs tables: section instead
