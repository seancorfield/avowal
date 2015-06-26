<cfoutput>
  <cfset f = new avowal.future( function() { sleep( 5000 ); return 42 } ) />
  <p>Future created: done yet? #f.isDone()#</p>
  <p>...</p>
  <p>Result is #f.get()#</p>
</cfoutput>
