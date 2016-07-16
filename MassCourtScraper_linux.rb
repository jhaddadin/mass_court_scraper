require 'rubygems'
require 'nokogiri'
require 'csv'
require 'open-uri'
require 'date'
require 'fileutils'
require 'watir'
require 'watir-webdriver'

def scrapecase(docketnumber)
  @docketnumber = docketnumber.to_s
  @year = $year
  
  # Count the number of characters in @docketnumber
  # Subtract the number of characters in @docketnumber from 5
  # Insert a zero character to the beginning of @docketnumber once for each missing zero
  @missingzeros = 5 - @docketnumber.length
  @missingzeros.times do
    @docketnumber.insert(0, '0')
  end
  
  @fulldocketnumber = "#{$year}#{$courtcodes[$division]}CV#{@docketnumber}"
  
  # Navigate to the search page and search for the case
  $browser.link(:text => "Search").click
  sleep 5
  $browser.text_field(:id => "caseDscr").set "#{@fulldocketnumber}"
  $browser.button(:name => "submitLink").click

  if $browser.text.include? 'No Matches Found'
    puts "There were no cases matching docket number #{@fulldocketnumber}."
    $lastdocket = $lastdocket + 1
	if $redflag == "Raised"
		$nomatches = $nomatches + 1
	end
	$redflag = "Raised"
    sleep 8
  else
    # Parse the results
    @docketarray = []
    @results = Nokogiri::HTML($browser.html)
    @caseinfo = @results.css("//table[@id=grid]//tr")
    @caseinfo.each{|item| @docketarray << item.css('td').map{|td| td.text.strip}}
    @docketarray.each{|subarray| subarray.delete("")}
    @docketarray.delete_at(0)

    # Format the case information
    @county = @docketarray[0][7]
    @date = @docketarray[0][2]
    @type = @docketarray[0][1]
    @initiating = @docketarray[0][3]
    @status = @docketarray[0][6]

	if @docketarray[0][0].include?("Showing")
		CSV.open("csv/#{$departmentfilename}_#{$divisionfilename}_#{$year}_errorlog.csv","ab") do |csv|
		  csv << [@fulldocketnumber]
		end
		puts ""
		puts "********************************"
		puts "Added #{@fulldocketnumber} to the error log."
		puts "********************************"
		puts ""
		$lastdocket = $lastdocket + 1
		$redflag = "Lowered"
	else
		$browser.link(:id => "grid$row:1$cell:2$link").click
		sleep 8

		# Save the case title
		@detailspage = Nokogiri::HTML($browser.html)
		@casetitle = @detailspage.xpath("//*[@id='caseDetailHeader']/div[1]/h2/text()").text.strip
		@casetitle.sub!(/\S+\d /,"")

		# Format an array of case information
		@casearray = [@county, @fulldocketnumber, @date, @casetitle, @type, @initiating, @status, $division, $department]

		# Save case information to a CSV file
		CSV.open("csv/#{$departmentfilename}_#{$divisionfilename}_#{$year}_case_list.csv","ab") do |csv|
		  csv << @casearray
		end
		puts "Wrote case data to a CSV file for #{@fulldocketnumber}"
			
		# Save the party information to a csv file
		@docketarray.each{|subarray|
		  CSV.open("csv/#{$departmentfilename}_#{$divisionfilename}_#{$year}_party_list.csv","ab") do |csv|
			csv << [@fulldocketnumber, @county, @date, @type, subarray[4], subarray[5], @status]
		  end
		}
		puts "Wrote party data to a CSV file for #{@fulldocketnumber}"
		
		# Save the HTML file
		File.open("files/#{@fulldocketnumber}.html",'w') {|f| f.write $browser.html }
		puts "Downloaded HTML page for #{@fulldocketnumber}."
		puts ""
		
		# Advance to the next case
		$lastdocket = $lastdocket + 1
		$redflag = "Lowered"
	end
  end
end

departments = {1 => "BMC", 2 => "District Court", 3 => "Housing Court", 4 => "Land Court Department", 5 => "Probate and Family Court", 6 => "The Superior Court"}

divisions = {"BMC" => ["BMC Brighton", "BMC Charlestown", "BMC Dorchester", "BMC East Boston", "BMC Roxbury", "BMC South Boston", "BMC West Roxbury", "Boston Municipal Central Court"], "District Court" => [], "Housing Court" => ["Boston Housing Court", "Northeast Housing Court", "Southeast Housing Court", "Western Housing Court", "Worcester Housing Court"], "Land Court Department" => ["Land Court Division"], "Probate and Family Court" => [], "The Superior Court" => ["Barnstable County", "Berkshire County", "Bristol County", "Dukes County", "Essex County", "Franklin County", "Hampden County", "Hampshire County", "Middlesex County", "Nantucket County", "Norfolk County", "Plymouth County", "Suffolk County Civil", "Worcester County"]}

$courtcodes = {"Barnstable County" => "72", "Berkshire County" => "76", "Bristol County" => "73", "Dukes County" => "74", "Essex County" => "77", "Franklin County" => "78", "Hampden County" => "79", "Hampshire County" => "80", "Middlesex County" => "81", "Nantucket County" => "75", "Norfolk County" => "82", "Plymouth County" => "83", "Suffolk County Civil" => "84", "Worcester County" => "85"}

# Select the court department
puts ""
puts ""
puts "Please select the court department:"
puts "1. BMC"
puts "2. District Court"
puts "3. Housing Court"
puts "4. Land Court Department"
puts "5. Probate and Family Court"
puts "6. The Superior Court"
$department = gets
$department = $department.chomp.to_i
$department = departments[$department]
$departmentfilename = $department.delete(" ")

# Select the court division
puts ""
puts "Please select the court division:"
$counter = 1

divisions[$department].each{|subarray|
	@stringcounter = $counter.to_s
	puts "#{@stringcounter}. #{subarray}"
	$counter = $counter + 1
	}
	
$division = gets
$division = $division.chomp.to_i - 1
$division = divisions[$department][$division]
$divisionfilename = $division.delete(" ")

# Select the year
puts ""
puts "Please select the year (last two digits)"
$year = gets
$year = $year.chomp

# Select the first docket number to scrape
puts ""
puts "Specify the first docket number you wish to scrape:"
$lastdocket = gets
$lastdocket = $lastdocket.chomp.to_i

# Select the last docket number to scrape
puts ""
puts "Specify the last docket number your wish to scrape:"
$upperlimit = gets
$upperlimit = $upperlimit.chomp.to_i

# Open the Superior Court website
$browser = Watir::Browser.new :firefox
$browser.goto 'http://www.masscourts.org'
sleep 30

# Select the court department and court division
# Navigate to case number search
# Fill in the docket number and click the search button
$browser.select_list(:name => "sdeptCd").select $department
sleep 3
$browser.select_list(:name => "sdivCd").select $division
sleep 3
$browser.link(:text => "Case Number").click
sleep 3
$browser.text_field(:id => "caseDscr").set "#{$year}#{$courtcodes[$division]}CV00005"
sleep 3
$browser.button(:name => "submitLink").click

$redflag = "Lowered"
$nomatches = 0

while ($lastdocket < $upperlimit) && ($nomatches < 10)
  scrapecase($lastdocket)
end