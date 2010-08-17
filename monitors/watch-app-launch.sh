#!/bin/bash
# Monitors and reports how long it takes to launch applications

IFS="
"

echo '<html>
<head>
<title>Table Pending</title>
</head>
<script>

function setTitle() {
	window.setTimeout(function() {
		document.title = "Table Populate";
	}, 500);
}

function populateTable() {
	var body = document.getElementsByTagName("body")[0];
	var table = document.createElement("table");
	var tableBody = document.createElement("tbody");

	for (var i = 0; i < 100; i++) {
		var row = document.createElement("tr");

		for (var j = 0; j < 100; j++) {
			var cell = document.createElement("td");
			var cellText = document.createTextNode(i+"+"+j);
			cell.appendChild(cellText);
			row.appendChild(cell);
		}

		tableBody.appendChild(row);
	}

	table.appendChild(tableBody);
	body.appendChild(table);
}
</script>
</head>
<body onload="populateTable()">
<script>
	window.addEventListener("DOMContentLoaded", setTitle, false);
</script>
</body>
</html>' > /tmp/firefox-table.html

while [ 1 ]; do
for COMMAND_SPEC in `grep ^C:: $0`; do
	NAME=`echo $COMMAND_SPEC | awk -F :: '{print $2}'`
	COMMAND=`echo $COMMAND_SPEC | awk -F :: '{print $3}'`
	ARGS=`echo $COMMAND_SPEC | awk -F :: '{print $4}'`
	EXIT_ACTION=`echo $COMMAND_SPEC | awk -F :: '{print $5}'`
	EXIT_ARG=`echo $COMMAND_SPEC | awk -F :: '{print $6}'`
	EXIT_EXTRAARG=`echo $COMMAND_SPEC | awk -F :: '{print $7}'`

	echo "#!/bin/bash
exec $COMMAND $ARGS" > /tmp/$$.script
	chmod u+x /tmp/$$.script
	START=`date +%s`
	/tmp/$$.script &
	PID=$!
	case $EXIT_ACTION in
	exit)
		while [ "`ps h -p $PID`" != "" ]; do
			sleep 0.2
		done
		;;
	wmctrl-window)
		while [ "`wmctrl -l -p | grep \"$EXIT_ARG\" | grep \" $PID \"`" = "" ]; do
			sleep 0.2
		done
		if [ "$EXIT_EXTRAARG" != "" ]; then
			sleep $EXIT_EXTRAARG
		fi
		WID=`wmctrl -l -p | grep "$EXIT_ARG" | grep " $PID " | awk '{print $1}'`
		wmctrl -i -c $WID
		while [ "`ps h -p $PID`" != "" ]; do
			sleep 0.2
		done
		;;
	*)
		echo WARNING: Unknown exit action $EXIT_ACTION
		;;
	esac
	END=`date +%s`

	rm /tmp/$$.script
	echo $NAME $(($END-$START))
done
done

exit

# Following is command specifications to run in order
C::firefox-table::firefox::/tmp/firefox-table.html::wmctrl-window::Table Populate - Mozilla Firefox::
C::evolution-wait30::evolution::::wmctrl-window::Evolution::30
C::gnome-terminal-find::gnome-terminal::--disable-factory -e "find /usr/share -type f"::exit::::
