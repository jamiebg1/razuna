<!---
*
* Copyright (C) 2005-2008 Razuna
*
* This file is part of Razuna - Enterprise Digital Asset Management.
*
* Razuna is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Razuna is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero Public License for more details.
*
* You should have received a copy of the GNU Affero Public License
* along with Razuna. If not, see <http://www.gnu.org/licenses/>.
*
* You may restribute this Program with a special exception to the terms
* and conditions of version 3.0 of the AGPL as described in Razuna's
* FLOSS exception. You should have received a copy of the FLOSS exception
* along with Razuna. If not, see <http://www.razuna.com/licenses/>.
*
--->
<cfcomponent output="false" extends="extQueryCaching">

<!--- List fields --->
<cffunction name="get" output="false" access="public">
	<cfargument name="thestruct" type="struct">
		<cfquery datasource="#variables.dsn#" name="qry" cachename="f_get_#session.hostid#" cachedomain="#session.theuserid#_customfields">
		SELECT c.cf_id, c.cf_type, c.cf_order, c.cf_enabled, c.cf_show, ct.cf_text
		FROM #session.hostdbprefix#custom_fields c, #session.hostdbprefix#custom_fields_text ct
		WHERE c.cf_id = ct.cf_id_r
<!--- 		AND ct.lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="1"> --->
		AND c.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		ORDER BY c.cf_order
		</cfquery>
	<cfreturn qry>
</cffunction>

<!--- Add field --->
<cffunction name="add" output="false" access="public">
	<cfargument name="thestruct" type="struct">
		<!--- Create a new field id --->
		<!--- <cfinvoke component="global" method="getsequence" returnvariable="newid" database="#variables.database#" dsn="#variables.dsn#" thetable="#session.hostdbprefix#custom_fields" theid="cf_id"> --->
		<cfset newcfid = createuuid()>
		<!--- Add one up for order --->
		<cfquery datasource="#variables.dsn#" name="neworder">
		SELECT 
		<cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2">NVL<cfelseif variables.database EQ "mysql">ifnull<cfelseif variables.database EQ "mssql">isnull</cfif>(max(cf_order),0) + 1 AS theorder
		FROM #session.hostdbprefix#custom_fields
		WHERE host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- Insert record --->
		<cfquery datasource="#variables.dsn#">
		INSERT INTO #session.hostdbprefix#custom_fields
		(cf_id, cf_type, cf_order, cf_enabled, cf_show, cf_group, host_id)
		VALUES(
		<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#newcfid#">,
		<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.cf_type#">,
		<cfqueryparam cfsqltype="cf_sql_numeric" value="#neworder.theorder#">,
		<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.cf_enabled#">,
		<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.cf_show#">,
		<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.cf_group#">,
		<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		)
		</cfquery>
		<!--- Add text to related db --->
		<cfloop list="#arguments.thestruct.langcount#" index="langindex">
			<cfset thetext="arguments.thestruct.cf_text_" & "#langindex#">
			<cfif thetext CONTAINS "#langindex#">
				<cftransaction>
					<cfquery datasource="#variables.dsn#">
					INSERT INTO #session.hostdbprefix#custom_fields_text
					(cf_id_r, lang_id_r, cf_text, host_id, rec_uuid)
					VALUES(
					<cfqueryparam value="#newcfid#" cfsqltype="CF_SQL_VARCHAR">,
					<cfqueryparam value="#langindex#" cfsqltype="cf_sql_numeric">,
					<cfqueryparam value="#evaluate(thetext)#" cfsqltype="cf_sql_varchar">,
					<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">,
					<cfqueryparam value="#createuuid()#" CFSQLType="CF_SQL_VARCHAR">
					)
					</cfquery>
				</cftransaction>
			</cfif>
		</cfloop>
		<!--- Flush Cache --->
		<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_customfields" />
	<cfreturn />
</cffunction>

<!--- Get fields for the detail view of assets --->
<cffunction name="getfields" output="false" access="public">
	<cfargument name="thestruct" type="struct">
		<cfquery datasource="#variables.dsn#" name="qry" cachename="f_getfields_#session.hostid##arguments.thestruct.cf_show##session.thelangid##arguments.thestruct.file_id#" cachedomain="#session.theuserid#_customfields">
		SELECT c.cf_id, c.cf_type, c.cf_order, ct.cf_text, cv.cf_value
		FROM #session.hostdbprefix#custom_fields_text ct, #session.hostdbprefix#custom_fields c 
		LEFT JOIN #session.hostdbprefix#custom_fields_values cv ON cv.cf_id_r = c.cf_id AND cv.asset_id_r = '#arguments.thestruct.file_id#'
		WHERE c.cf_id = ct.cf_id_r
		AND lower(c.cf_enabled) = <cfqueryparam cfsqltype="cf_sql_varchar" value="t">
		AND (
			lower(c.cf_show) = <cfqueryparam cfsqltype="cf_sql_varchar" value="all">
			OR lower(c.cf_show) = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.cf_show#">
			)
		AND ct.lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.thelangid#">
		AND c.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		ORDER BY c.cf_order
		</cfquery>
	<cfreturn qry>
</cffunction>

<!--- Get fields for the search view --->
<cffunction name="getfieldssearch" output="false" access="public">
	<cfargument name="thestruct" type="struct">
		<cfquery datasource="#variables.dsn#" name="qry" cachename="f_getfieldssearch_#session.hostid##session.thelangid#" cachedomain="#session.theuserid#_customfields">
		SELECT c.cf_id, c.cf_type, c.cf_order, ct.cf_text
		FROM #session.hostdbprefix#custom_fields_text ct, #session.hostdbprefix#custom_fields c 
		WHERE c.cf_id = ct.cf_id_r
		AND lower(c.cf_enabled) = <cfqueryparam cfsqltype="cf_sql_varchar" value="t">
		AND ct.lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.thelangid#">
		AND c.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		GROUP BY c.cf_id, c.cf_type, c.cf_order, ct.cf_text
		ORDER BY c.cf_order
		</cfquery>
	<cfreturn qry>
</cffunction>

<!--- Get detail view --->
<cffunction name="getdetail" output="false" access="public">
	<cfargument name="thestruct" type="struct">
		<cfquery datasource="#variables.dsn#" name="qry" cachename="f_getdetail_#session.hostid##arguments.thestruct.cf_id#" cachedomain="#session.theuserid#_customfields">
		SELECT c.cf_id, c.cf_type, c.cf_order, c.cf_show, c.cf_enabled, c.cf_group, ct.cf_text, ct.lang_id_r
		FROM #session.hostdbprefix#custom_fields_text ct, #session.hostdbprefix#custom_fields c
		WHERE c.cf_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.cf_id#">
		AND ct.cf_id_r = c.cf_id
		AND c.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
	<cfreturn qry>
</cffunction>

<!--- Save field values --->
<cffunction name="savevalues" output="false" access="public">
	<cfargument name="thestruct" type="struct">
	<!--- Loop over the fields which only are custom fields --->
	<cfloop collection="#arguments.thestruct#" item="i">
		<cfif i CONTAINS "cf_">
			<!--- Remove the cf_ part so we only get the id --->
			<cfset theid = replacenocase("#i#", "cf_", "", "ALL")>
			<!--- Insert or update --->
			<cfquery datasource="#variables.dsn#" name="qry">
			SELECT cf_id_r
			FROM #session.hostdbprefix#custom_fields_values
			WHERE cf_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
			AND asset_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.file_id#">
			</cfquery>
			<!--- Insert --->
			<cfif qry.recordcount EQ 0>
				<cfquery datasource="#variables.dsn#">
				INSERT INTO #session.hostdbprefix#custom_fields_values
				(cf_id_r, asset_id_r, cf_value, host_id, rec_uuid)
				VALUES(
				<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">,
				<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.file_id#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct[i]#">,
				<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">,
				<cfqueryparam value="#createuuid()#" CFSQLType="CF_SQL_VARCHAR">
				)
				</cfquery>
			<!--- Update --->
			<cfelse>
				<cfquery datasource="#variables.dsn#">
				UPDATE #session.hostdbprefix#custom_fields_values
				SET cf_value = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct[i]#">
				WHERE cf_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
				AND asset_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.file_id#">
				</cfquery>
			</cfif>
		</cfif>
	</cfloop>
	<!--- Flush Cache --->
	<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_customfields" />
	<!--- Lucene is indexing these values in the video.cfc already thus we are done here --->
</cffunction>

<!--- Update field --->
<cffunction name="update" output="false" access="public">
	<cfargument name="thestruct" type="struct">
		<!--- Update record --->
		<cfquery datasource="#variables.dsn#">
		UPDATE #session.hostdbprefix#custom_fields
		SET
		cf_type = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.cf_type#">, 
		cf_enabled = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.cf_enabled#">, 
		cf_show = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.cf_show#">, 
		cf_group = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.cf_group#">
		WHERE cf_id = <cfqueryparam value="#arguments.thestruct.cf_id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- Add text to related db --->
		<cfloop list="#arguments.thestruct.langcount#" index="langindex">
			<cfset thetext="arguments.thestruct.cf_text_" & "#langindex#">
			<cfif thetext CONTAINS "#langindex#">
				<cfquery datasource="#variables.dsn#">
				UPDATE #session.hostdbprefix#custom_fields_text
				SET cf_text = <cfqueryparam value="#evaluate(thetext)#" cfsqltype="cf_sql_varchar">
				WHERE cf_id_r = <cfqueryparam value="#arguments.thestruct.cf_id#" cfsqltype="CF_SQL_VARCHAR">
				AND lang_id_r = <cfqueryparam value="#langindex#" cfsqltype="cf_sql_numeric">
				</cfquery>
			</cfif>
		</cfloop>
		<!--- Flush Cache --->
		<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_customfields" />
	<cfreturn />
</cffunction>

<!--- Delete --->
<cffunction name="delete" access="public" output="false" returntype="void">
	<cfargument name="thestruct" type="struct">
	<!--- Rearrange the order --->
	<cfquery datasource="#variables.dsn#">
	UPDATE #session.hostdbprefix#custom_fields
	SET cf_order = cf_order - 1
	WHERE cf_order > <cfqueryparam value="#arguments.thestruct.order#" cfsqltype="cf_sql_numeric">
	AND cf_order <cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2"><><cfelse>!=</cfif> 1
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- remove record --->
	<cfquery datasource="#Variables.dsn#">
	DELETE FROM #session.hostdbprefix#custom_fields
	WHERE cf_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.id#">
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Flush Cache --->
	<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_customfields" />
</cffunction>

</cfcomponent>