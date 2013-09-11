/**
 *        The Institute for Advanced Technology in the Humanities
 *        
 *        Copyright 2013 University of Virginia. Licensed under the Educational Community License, Version 2.0 (the
 *        "License"); you may not use this file except in compliance with the License. You may obtain a copy of the
 *        License at
 *        
 *        http://opensource.org/licenses/ECL-2.0
 *        http://www.osedu.org/licenses/ECL-2.0
 *        
 *        Unless required by applicable law or agreed to in writing, software distributed under the License is
 *        distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See
 *        the License for the specific language governing permissions and limitations under the License.
 *
 *
 */
package edu.virginia.iath.snac.helpers;

import java.text.ParseException;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;

import org.apache.commons.lang3.time.DateFormatUtils;
import org.apache.commons.lang3.time.DateUtils;

/**
 * Date parser for Java based on conventions used in SNAC.   Given a string, tries multiple parsings for a date,
 * converting them into a Java Date object.  Dates are returned in an ISO standard format, YYYY-MM-DD.
 * 
 * @author Robbie Hott
 *
 */
public class DateParserHelper {
	
	private String dateString = null;
	private String[] dateStr = null;
	private String[] origDateStr = null;
	private Date[] notBefore = null;
	private Date[] notAfter = null;
	private Date[] dates = null;
	private ArrayList<ArrayList<String>> dateStrModifier = null;
	private String outputFormat = "yyyy-MM-dd";
	

	public DateParserHelper(String d) {
		// Initialize dates
		dates = new Date[2];
		notBefore = new Date[2];
		notAfter = new Date[2];
		dateStr = new String[2];
		origDateStr = new String[2];
		dateStrModifier = new ArrayList<ArrayList<String>>();
		
		dates[0] = null; dates[1] = null;
		notBefore[0] = null; notBefore[1] = null;
		notAfter[0] = null; notAfter[1] = null;
		
		// Store the date string locally
		dateString = d.trim();
		
		// Parse the dates into Date objects
		runParser();
	}
	
	private void runParser() {
		// Check for date range.  If so, parse separately
		dateStringPreprocess();
		
		if (dateString.contains("-")) {
			dateStr[0] = dateString.substring(0, dateString.indexOf("-")).trim();
			dateStr[1] = dateString.substring(dateString.indexOf("-") + 1).trim();
			origDateStr[0] = dateStr[0];
			origDateStr[1] = dateStr[1];
			dateStrModifier.add(new ArrayList<String>());
			dateStrModifier.add(new ArrayList<String>());
			
			// parse the two dates
			parseDate(0);
			parseDate(1);
		} else {
			dateStr[0] = dateString.trim();
			origDateStr[0] = dateStr[0];
			dateStr[1] = null;
			origDateStr[1] = null;
			dateStrModifier.add(new ArrayList<String>());
			
			// parse the date
			parseDate(0);
		}
	}

	public boolean isRange() {
		return dates[1] != null;
	}

	public boolean wasParsed() {
		return dates[0] != null;
	}

	public String firstDate() {
		return getOutputString(dates[0]);
	}

	public String secondDate() {
		return getOutputString(dates[1]);
	}

	public String firstNotBeforeDate() {
		return getOutputString(notBefore[0]);
	}

	public String secondNotBeforeDate() {
		return getOutputString(notBefore[1]);
	}

	public String firstNotAfterDate() {
		return getOutputString(notAfter[0]);
	}

	public String secondNotAfterDate() {
		return getOutputString(notAfter[1]);
	}
	
	public String getDate() {
		return getOutputString(dates[0]);
	}
	
	public String firstOriginalDate() {
		return origDateStr[0];
	}

	public String secondOriginalDate() {
		return origDateStr[1];
	}
	
	private void dateStringPreprocess() {
		
		// Handle dates surrounded with []
		if (dateString.endsWith("]") && dateString.startsWith("["))
			dateString = dateString.substring(1, dateString.length() -1);
		
	}
	
	private void parsePreprocess(int i) {

		/**
		 * Fixes for non-standardized date formats
		 */
		// Handle non-standard month representations
		dateStr[i] = dateStr[i].replace("Sept.", "Sep.");
		// Handle dates surrounded with []
		if (dateStr[i].endsWith("]") && dateStr[i].startsWith("["))
			dateStr[i] = dateStr[i].substring(1, dateStr[i].length() -1);
		
	
		/**
		 * Handling actual date keywords such as circa, centuries, questions, etc
		 */
		// Look for and handle the circa/Circa/... keyword
		if (dateStr[i].contains("circa") || dateStr[i].contains("Circa") || dateStr[i].contains("ca.")) {
			dateStrModifier.get(i).add("circa");
			
			dateStr[i] = dateStr[i].replace("circa", "");
			dateStr[i] = dateStr[i].replace("Circa", "");
			dateStr[i] = dateStr[i].replace("ca.", "");
		}
		
		// Look for decades (s after the date)
		if (dateStr[i].endsWith("s")) {
			dateStrModifier.get(i).add("decade");
			
			dateStr[i] = dateStr[i].substring(0,dateStr[i].length() -1);
		}
		
		// Look for fuzzy dates (some form of "[?]", "(?)", ...)
		if (dateStr[i].contains("?")) {
			dateStrModifier.get(i).add("fuzzy");
			
			dateStr[i] = dateStr[i].replace("[?]", "");
			dateStr[i] = dateStr[i].replace("(?)", "");
			dateStr[i] = dateStr[i].replace("?", "");
		}
		
		// Look for seasons
		String lowercase = dateStr[i].toLowerCase();
		if (lowercase.contains("fall") || lowercase.contains("autumn")) {
			dateStrModifier.get(i).add("season");
			dateStrModifier.get(i).add("fall");

			dateStr[i] = dateStr[i].replace("fall", "");
			dateStr[i] = dateStr[i].replace("autumn", "");
			dateStr[i] = dateStr[i].replace("Fall", "");
			dateStr[i] = dateStr[i].replace("Autumn", "");
		}
		if (lowercase.contains("spring")) {
			dateStrModifier.get(i).add("season");
			dateStrModifier.get(i).add("spring");

			dateStr[i] = dateStr[i].replace("spring", "");
			dateStr[i] = dateStr[i].replace("Spring", "");
		}
		if (lowercase.contains("winter")) {
			dateStrModifier.get(i).add("season");
			dateStrModifier.get(i).add("winter");

			dateStr[i] = dateStr[i].replace("winter", "");
			dateStr[i] = dateStr[i].replace("Winter", "");
		}
		if (lowercase.contains("summer")) {
			dateStrModifier.get(i).add("season");
			dateStrModifier.get(i).add("summer");

			dateStr[i] = dateStr[i].replace("summer", "");
			dateStr[i] = dateStr[i].replace("Summer", "");
		}

		/**
		 * Trim out extra punctuation 
		 */
		// Quick fixes, including ending with a period
		if (dateStr[i].endsWith("."))
			dateStr[i] = dateStr[i].substring(0, dateStr[i].length() -1);
		if (dateStr[i].endsWith(","))
			dateStr[i] = dateStr[i].substring(0, dateStr[i].length() -1);
		dateStr[i] = dateStr[i].replace("(", "");
		dateStr[i] = dateStr[i].replace(")", "");
		dateStr[i] = dateStr[i].replace("'", "");
		dateStr[i] = dateStr[i].replace("  ", " ");
		
		// Trim down before returning, just to be sure.
		dateStr[i] = dateStr[i].trim();
		
	}
	
	private void parseDate(int i) {
		//dateStrModifier[i] = null;
		
		// preprocess the date string, including handling boundary cases and special date types.
		parsePreprocess(i);
		
		try {
			// Currently we are ignoring "-" in the text, since that is used for ranges in dates
			dates[i] = DateUtils.parseDate(dateStr[i].trim(),
					"yyyy", "yyyy,", /*"yyyy-MM", "yyyy-M", "yyyy-M-d", "yyyy-M-dd", "yyyy-MM-d", "yyyy-MM-dd",*/ // standard dates
					"MMMMM dd, yyyy", "MMM dd, yyyy", "MMM. d, yyyy", "MMM dd yyyy", "MMMMM dd, yyyy", "yyyy MMM dd", "yyyy MMM. dd",
					"dd MMM, yyyy", "dd MMMMM, yyyy", "yyyy, MMM dd", "yyyy, MMMMM dd", "yyyy, MMM. dd",
					"MMMMM yyyy", "MMM yyyy", "yyyy, MMM. d", "yyyy, MMMMM d", "yyyy, MMM", "yyyy, MMM.", "yyyy, MMMMM",
					"yyyy, dd MMM.", "yyyy, dd MMMMM", "yyyy, dd MMM", "yyyy, MMM.dd", "yyyy,MMM.dd", "yyyy,MMM. dd",
					"yyyy, MMMd", "yyyy, MMMMMd", "yyyy, MMM.d", "yyyyMMMd", "yyyyMMMMMd", "yyyy, MMM, d", "yyyy. MMM. d",
					"yyyy MMM", "yyyy, MMM.", "yyyy MMMMM", "yyyy, MMMMM", "yyyy,MMMMM dd", "yyyy,MMM dd", "yyyy,MMM. dd"
					);
			
			handleModifiers(i);
			updateOutputFormat();
			
		} catch (ParseException e) {
			dates[i] = null;
		}
	}
	
	private void handleModifiers(int i) {
		if (!dateStrModifier.get(i).isEmpty()) {
			if (dateStrModifier.get(i).contains("circa")) {
				Calendar d = Calendar.getInstance();
				d.setTime(dates[i]);
				d.add(Calendar.YEAR, -3);
				notBefore[i] = d.getTime();
				d.setTime(dates[i]);
				d.add(Calendar.YEAR, 3);
				notAfter[i]  = d.getTime();
				
			}
			
			if (dateStrModifier.get(i).contains("decade")) {
				// Create a calendar for this date
				Calendar d = Calendar.getInstance();
				d.setTime(dates[i]);
				int year = d.get(Calendar.YEAR);
				if (year % 100 == 0) { // dealing with centuries
					notBefore[i] = d.getTime();
					d.add(Calendar.YEAR, 99);
					notAfter[i] = d.getTime();
				} else if (year % 10 == 0) { // dealing with decades
					notBefore[i] = d.getTime();
					d.add(Calendar.YEAR, 9);
					notAfter[i] = d.getTime();
				}
			}
			
			if (dateStrModifier.get(i).contains("season")) {
				String season = dateStrModifier.get(i).get(dateStrModifier.get(i).indexOf("season") + 1);
				Calendar d = Calendar.getInstance();
				d.setTime(dates[i]);
				int year = d.get(Calendar.YEAR);
				
				Date[] seasonDates = getSeasonDates(season, year);
				notBefore[i] = seasonDates[0];
				notAfter[i] = seasonDates[1];
			}
		}
	}
	
	private String getOutputString(Date d) {
		return (d == null) ? "null" : DateFormatUtils.format(d, outputFormat);
	}
	
	private void updateOutputFormat() {
		switch(dateStr[0].split("[\\s.,-]+").length) {
			case 1:
				outputFormat = "yyyy";
				break;
			case 2:
				outputFormat = "yyyy-MM";
				break;
			default:
				outputFormat = "yyyy-MM-dd";	
		}
	}
	
	private Date[] getSeasonDates(String seasonStr, int year) {
		Date[] seasonDates = new Date[2];
		String season = seasonStr.toLowerCase().trim();
		
		Calendar d = Calendar.getInstance();
		
		if (season.equals("winter")) {
			d.set(year, 12, 21);
			seasonDates[0] = d.getTime();
			d.set(year + 1, 3, 19);
			seasonDates[1] = d.getTime();
			
		} else if (season.equals("spring")) {
			d.set(year, 3, 20);
			seasonDates[0] = d.getTime();
			d.set(year, 6, 20);
			seasonDates[1] = d.getTime();
			
		} else if (season.equals("fall") || season.equals("autumn")) {
			d.set(year, 9, 22);
			seasonDates[0] = d.getTime();
			d.set(year, 12, 20);
			seasonDates[1] = d.getTime();
			
		} else if (season.equals("summer")) {
			d.set(year, 6, 21);
			seasonDates[0] = d.getTime();
			d.set(year, 9, 21);
			seasonDates[1] = d.getTime();
			
		}
		
		return seasonDates;
	}
	

}
