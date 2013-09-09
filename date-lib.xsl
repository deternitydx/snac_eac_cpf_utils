<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0"
                xmlns:lib="http://example.com/"
                xmlns:rel="http://example.com/relators"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:saxon="http://saxon.sf.net/"
                xmlns:functx="http://www.functx.com"
                xmlns:marc="http://www.loc.gov/MARC21/slim"
                xmlns:eac="urn:isbn:1-931666-33-4"
                xmlns:madsrdf="http://www.loc.gov/mads/rdf/v1#"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:mads="http://www.loc.gov/mads/"
                xmlns:snacwc="http://socialarchive.iath.virginia.edu/worldcat"
                exclude-result-prefixes="eac lib xs saxon xsl madsrdf rdf mads functx marc snacwc rel"
                >

    <xsl:variable name="this_year" select="year-from-date(current-date())"/>    
		<xsl:variable name="debug" select="false()"/>
    

    <xsl:variable name="av_mergedRecord" select="'http://socialarchive.iath.virginia.edu/control/term#MergedRecord'"/>
    <xsl:variable name="av_suspiciousDate" select="'http://socialarchive.iath.virginia.edu/control/term#SuspiciousDate'"/>
    <xsl:variable name="av_active " select="'http://socialarchive.iath.virginia.edu/control/term#Active'"/>
    <xsl:variable name="av_born" select="'http://socialarchive.iath.virginia.edu/control/term#Birth'"/>
    <xsl:variable name="av_died" select="'http://socialarchive.iath.virginia.edu/control/term#Death'"/>
    <xsl:variable name="av_associatedSubject" select="'http://socialarchive.iath.virginia.edu/control/term#AssociatedSubject'"/>
    <xsl:variable name="av_associatedPlace" select="'http://socialarchive.iath.virginia.edu/control/term#AssociatedPlace'"/>
    <xsl:variable name="av_extractRecordId" select="'http://socialarchive.iath.virginia.edu/control/term#ExtractedRecordId'"/>
    <xsl:variable name="av_Leader06" select="'http://socialarchive.iath.virginia.edu/control/term#Leader06'"/>
    <xsl:variable name="av_Leader07" select="'http://socialarchive.iath.virginia.edu/control/term#Leader07'"/>
    <xsl:variable name="av_Leader08" select="'http://socialarchive.iath.virginia.edu/control/term#Leader08'"/>
    <xsl:variable name="av_derivedFromRole" select="'http://socialarchive.iath.virginia.edu/control/term#DerivedFromRole'"/>


		<xsl:template name="tpt_parse_date">
        <xsl:param name="date"/>
        	<xsl:variable name="tokens">
        		<xsl:call-template name="lib:tpt_tokenize_dates">
               <xsl:with-param name="date" select="$date"/>
            </xsl:call-template>
          </xsl:variable>
          <xsl:call-template name="lib:tpt_output_date">
            <xsl:with-param name="tokens" select="$tokens"/>
          </xsl:call-template>
		</xsl:template>


    <xsl:template name="lib:tpt_tokenize_dates">
        <xsl:param name="date"/>
        <!-- 
             date parsing. Normalize various abbreviations and short
             hand. Support 1st, 2nd, 3rd, 4th century,
             
             1) Chew input string one token at a time with using a regular expression character class
             as separator. Put the tokens into a node set.
             
             2) Make several tranformation passes, each time copying "good" data to a new node set.
             
             3) Return the node set so that tpt_show_date can run rules on the
             final node set of tokens to build date elements.
             
             Examples: NNNN-NNNN, NNNN or N, NNNN(approx.), fl. NNNN, b. NNNN,
             d. NNNN, b. ca. NNNN, d. ca. NNNN, Nth cent., fl. Nth cent., Nth
             cent./Mth cent., nnnn(approx.) - nnnn, NNNNs.
        -->
        <xsl:if test="boolean(normalize-space($date))">
            <!-- break the date into tokens -->
            <xsl:variable name="token_1">
                <xsl:copy-of select="lib:tokenize(normalize-space($date))"/>
            </xsl:variable>

            <!-- Fix normal "or" and "century or" by creating new token "cyr" -->
            <xsl:variable name="pass_1b">
                <xsl:copy-of select="lib:pass_1b($token_1)"/>
            </xsl:variable>
            
            <!-- Deal with NNNNs as in 1870s as well as "or N", change 'fl' to 'active'. -->

            <xsl:variable name="pass_2">
                <xsl:copy-of select="lib:pass_2($pass_1b)"/>
            </xsl:variable>

            <!-- Normalize position of approx and turn related numeric tokens into 'num' -->
            <xsl:variable name="pass_2b">
                <xsl:copy-of select="lib:pass_2b($pass_2)"/>
            </xsl:variable>
            
            <!-- Fix century values. -->
            <xsl:variable name="pass_3">
                <xsl:copy-of select="lib:pass_3($pass_2b)"/>
            </xsl:variable>

            <!-- Turn remaining fully numeric tokens into @std, @val, and tok element value 'num'. -->
            <xsl:variable name="pass_4">
                <xsl:copy-of select="lib:pass_4($pass_3)"/>
            </xsl:variable>

            <!--
                Remove "active" tokens and mark entire date as active.  This needs to be the last step because
                it sets @is_active on every <tok> and (normally) parse steps fail to copy all the attributes
                of tokens.
            -->

            <xsl:copy-of select="lib:pass_5($pass_4)"/>

        </xsl:if>
    </xsl:template>


    <xsl:function name="lib:tokenize">
        <xsl:param name="date" as="xs:string?"/> 
        <!--
            For the purposes of initial tokenizing, everything is either separator or not-separator. If
            separator matches '-' then create a "-" token. If separator matches '/' then create an "or"
            token. "1601/2" is conceptually "1601 or 2". If - or / occur in some other context, bad things may
            happen. All other separators are discarded.
        -->
        <xsl:element name="orig_date">
            <xsl:value-of select="$date"/>
        </xsl:element>
        <xsl:analyze-string select="$date"
                            regex="([ ;/,\.\-\?:\(\)\[\]]+)|([^ ;/,\.\-\?:\(\)\[\]]+)">
            <xsl:matching-substring>
                <xsl:choose>

                    <xsl:when test="matches(regex-group(1), '-') or matches(regex-group(1), '\?')">
                        <!--
                            Separators can be '?', '-', or '?-' so we need a couple of if statements. Note
                            that the '?' if statement must be first. We do not support '-?'  because it seems
                            wrong. It could be accomodated by creating tokens in order with a for-each based
                            on the chars in regex-group(1).
                        -->
                        <xsl:if test="matches(regex-group(1), '\?')">
                            <xsl:element name="tok">?</xsl:element>
                        </xsl:if>
                        <xsl:if  test="matches(regex-group(1), '-')">
                            <xsl:element name="tok">-</xsl:element>
                        </xsl:if>
                    </xsl:when>

                    <xsl:when test="matches(regex-group(1), '/')">
                        <xsl:element name="tok">or</xsl:element>
                    </xsl:when>

                    <xsl:when test="matches(regex-group(2), 'approx')">
                        <!--
                            This is not a keyword, but simply a normalized token. The token is 'approx'. Do
                            not change to 'approximately' unless you are prepared to change and fix all the
                            other code relying on 'approx'. In fact, if you want to change it, change it to
                            'aprx_tok' or something distinctly token-ish.
                        -->
                        <xsl:element name="tok">approx</xsl:element>
                    </xsl:when>

                    <xsl:when test="string-length(regex-group(2)) > 0">
                        <!-- <tok> -->
                        <xsl:element name="tok">
                            <xsl:value-of select="lower-case(normalize-space(regex-group(2)))"/>
                        </xsl:element>
                        <!-- </tok> -->
                    </xsl:when>

                </xsl:choose>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
                <xsl:element name="untok">
                    <xsl:value-of select="normalize-space(.)"/>
                </xsl:element>
            </xsl:non-matching-substring>
        </xsl:analyze-string>
    </xsl:function> <!-- end lib:tokenize -->


    <xsl:function name="lib:pass_1b">
        <xsl:param name="tokens" as="node()*"/> 
        <!-- 
             Disambiguate (normal "or") and ("century or") by making ("century or") into a token "cyr".
        -->
        <xsl:copy-of select="$tokens/orig_date"/>
        <xsl:copy-of select="$tokens/untok"/>
        <xsl:for-each select="$tokens/tok">
            <xsl:choose>

                <xsl:when test="text() = 'or' and following-sibling::tok[matches(text(), 'cent')]">
                    <xsl:element name="tok">
                        <xsl:text>cyr</xsl:text>
                    </xsl:element>
                </xsl:when>

                <xsl:otherwise>
                    <xsl:copy-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:function>

    <xsl:function name="lib:pass_2">
        <xsl:param name="tokens" as="node()*"/> 
        <!-- 
             Normalize several token types, fix approx. Process NNNNs (1870s) and "or N".
        -->
        <xsl:copy-of select="$tokens/orig_date"/>
        <xsl:copy-of select="$tokens/untok"/>
        <xsl:for-each select="$tokens/tok">
            <xsl:variable name="p_tok"
                          select="preceding-sibling::tok[1]"/>
            <xsl:variable name="f_tok"
                          select="following-sibling::tok[1]"/>

            <xsl:choose>

                <!-- Make sure this won't match 1st -->
                <xsl:when test="matches(., '\d+s$')">
                    <xsl:analyze-string select="."
                                        regex="(\d+)s">
                        <xsl:matching-substring>
                            <tok>
                                <xsl:attribute name="notBefore"><xsl:value-of select="lib:min_ess(regex-group(1))"/></xsl:attribute>
                                <xsl:attribute name="notAfter"><xsl:value-of select="lib:max_ess(regex-group(1))"/></xsl:attribute>
                                <xsl:attribute name="sep"><xsl:text>s</xsl:text></xsl:attribute>
                                <xsl:attribute name="std" select="format-number(lib:min_ess(regex-group(1)), '0000')"/>
                                <xsl:attribute name="val" select="format-number(lib:min_ess(regex-group(1)), '0000')"/>
                                <xsl:text>num</xsl:text>
                            </tok>
                        </xsl:matching-substring>
                    </xsl:analyze-string>
                </xsl:when>

                <xsl:when test="matches(., '^\d+$') and $f_tok = 'or'">
                    <!-- if a number and if following is '-' (or whatever) we want that since it is used during analysis later. -->
                    <xsl:variable name="or_date"
                                  select="format-number(number(lib:date_cat(text(), following-sibling::tok[2])), '0000')"/>
                    <tok>
                        <xsl:attribute name="notBefore"><xsl:value-of select="."/></xsl:attribute>
                        <xsl:attribute name="notAfter"><xsl:value-of select="$or_date"/></xsl:attribute>
                        <!-- <xsl:attribute name="sep"><xsl:value-of select="concat('or ', following-sibling::tok[2])"/></xsl:attribute> -->
                        <xsl:attribute name="sep"><xsl:value-of select="concat(' or ', $or_date)"/></xsl:attribute>
                        <xsl:attribute name="std" select="format-number(., '0000')"/>
                        <xsl:attribute name="val" select="format-number(., '0000')"/>
                        <xsl:text>num</xsl:text>
                    </tok>
                </xsl:when>

                <xsl:when test="($p_tok = 'or') or (text() = 'or')">
                    <!--
                        Does first preceding tok match 'or'? For example "or 2" and this is token "2". If so,
                        we processed this already so we do not want to see it again. Same if this token
                        matches 'or'.
                    -->
                </xsl:when>

                <xsl:when test="matches(., '^\d+$') and $f_tok = '?'">
                    <!-- If a numeric token is followed by ? then do a date range. This code carefully avoids "18th cent.?" -->
                    <xsl:element name="tok">
                        <xsl:attribute name="notBefore"><xsl:value-of select="number(.) -1"/></xsl:attribute>
                        <xsl:attribute name="notAfter"><xsl:value-of select="number(.) + 1"/></xsl:attribute>
                        <!-- <xsl:attribute name="sep"><xsl:value-of select="'?'"/></xsl:attribute> -->
                        <xsl:attribute name="std" select="format-number(., '0000')"/>
                        <xsl:attribute name="val" select="format-number(., '0000')"/>
                        <xsl:text>num</xsl:text>
                    </xsl:element>
                </xsl:when>
                
                <xsl:when test="text() = '?'">
                    <!--
                        ? tokens have already been processed so throw them away.
                    -->
                </xsl:when>

                <xsl:when test="text() = 'ca' or text() = 'c' or text() = 'circa' or text() = 'approx'">
                    <xsl:element name="tok">
                        <xsl:text>approximately</xsl:text>
                    </xsl:element>
                </xsl:when>

                <xsl:when test="matches(., 'fl', 'i')">
                    <xsl:element name="tok">
                        <xsl:value-of select="'active'"/>
                    </xsl:element>
                </xsl:when>

                <xsl:otherwise>
                    <xsl:copy-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:function>

    <xsl:function name="lib:pass_2b">
        <xsl:param name="tokens" as="node()*"/> 
        <!-- 
             Resolve approx numerically, whether in leading or trailing position. Trailing is especially interesting: "1940
             approx - 1980" becomes "approx 1940 - 1980", but as a node list of tokens (of course).
        -->
        <xsl:copy-of select="$tokens/orig_date"/>
        <xsl:copy-of select="$tokens/untok"/>
        <xsl:for-each select="$tokens/tok">
            <xsl:variable name="p_tok"
                          select="preceding-sibling::tok[1]"/>
            <xsl:variable name="f_tok"
                          select="following-sibling::tok[1]"/>
            <xsl:choose>
                <xsl:when test="matches(. , '^\d+$') and ($p_tok = 'approximately' or $f_tok = 'approximately')">
                    <!--
                        Only for numeric tokens, if the preceding token is approx (in any form) then +3 -3 date
                        range. Ditto if following token is 'approx'. If the following token is 'approx' then
                        insert an 'approx' token before our date so this date will be just like a normal approx.
                        date.
                    -->
                    <xsl:if test="$f_tok = 'approximately'">
                        <xsl:element name="tok">
                            <xsl:text>approximately</xsl:text>
                        </xsl:element>
                    </xsl:if>
                    <xsl:element name="tok">
                        <xsl:attribute name="notBefore"><xsl:value-of select="number(.) - 3"/></xsl:attribute>
                        <xsl:attribute name="notAfter"><xsl:value-of select="number(.) + 3"/></xsl:attribute>
                        <xsl:attribute name="std" select="format-number(., '0000')"/>
                        <xsl:attribute name="val" select="format-number(., '0000')"/>
                        <xsl:text>num</xsl:text>
                    </xsl:element>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:copy-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:function>

                        
    <xsl:function name="lib:pass_3">
        <xsl:param name="tokens" as="node()*"/> 
        <xsl:copy-of select="$tokens/orig_date"/>
        <xsl:copy-of select="$tokens/untok"/>
        <!--
            This is a parsing pass to deal with ordinal century values. As far as I know, rdinals only occur
            in reference to century dates.  New: "1st/2nd century" and "1st century - 2nd century" and
            "1st-2nd century" all mean fromDate=1st toDate=2nd. See old_pass_3 for the previous code.
        -->
        <xsl:variable name="has_century">
            <xsl:if test="$tokens/tok = 'century'">
                <xsl:value-of select="true()"/>
            </xsl:if>
        </xsl:variable>

        <xsl:for-each select="$tokens/tok">
            <xsl:choose> 
                <xsl:when test="matches(text(), '\d+(st|nd|rd|th)') and $has_century">
                    <xsl:variable name="cent1"
                        select="lib:ordinal_number(text())"/>
                    <!--
                        The algebraic formula is only slightly confusing. In XSLT "/" is a path and "div" is
                        the division operator. No division here.
                    -->
                    <tok>
                        <xsl:attribute name="notBefore"><xsl:value-of select="(($cent1/num -1) * 100) + 1"/></xsl:attribute>
                        <xsl:attribute name="notAfter"><xsl:value-of select="$cent1/num * 100"/></xsl:attribute>
                        <xsl:attribute name="std" select="format-number((($cent1/num -1) * 100) + 1, '0000')"/>
                        <!-- Don't format-number for val since this is 1st, 2nd, etc. -->
                        <xsl:attribute name="val" select="concat(., ' century')"/>
                        <xsl:text>num</xsl:text>
                    </tok>
                </xsl:when>

                <!--
                    cyr becomes - (hyphen) since this is a date range "nnnn - nnnn", not a "nnnn or
                    nnnn". Later parsing phases treat "-" tokens very differently from "cyr" or "or" tokens,
                    so we're setting up the tokens to get the parse result we want.
                 -->
                <xsl:when test="text() = 'cyr'">
                    <tok>-</tok>
                </xsl:when>

                <xsl:when test="matches(text(), 'cent')">
                    <!-- nothing, skip -->
                </xsl:when>

                <xsl:otherwise>
                    <xsl:copy-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:function>

    <xsl:function name="lib:pass_4">
        <xsl:param name="tokens" as="node()*"/> 
        <!-- 
             Turn all fully numeric tokens into @std, @val, and tok element value 'num'.
        -->
        <xsl:copy-of select="$tokens/orig_date"/>
        <xsl:copy-of select="$tokens/untok"/>
        <xsl:for-each select="$tokens/tok">
            <xsl:choose>

                <xsl:when test="matches(text(), '^\d+$')">
                    <tok std="{format-number(., '0000')}"
                         val="{format-number(., '0000')}">
                        <xsl:text>num</xsl:text>
                    </tok>
                </xsl:when>

                <xsl:otherwise>
                    <xsl:copy-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:function>


    <xsl:function name="lib:pass_5">
        <xsl:param name="tokens" as="node()*"/> 
        <!-- 
             Remove tokens "active", and make the whole date active by putting an is_active attribute in every
             token. This is in some sense wasteful, but makes it really easy to figure out if this is an
             active date. It does preclude a mixed active+born/died date, but other things preclude that too.
        -->
        <xsl:copy-of select="$tokens/orig_date"/>
        <xsl:copy-of select="$tokens/untok"/>
        <xsl:variable name="is_active" as="xs:boolean">
                    <xsl:value-of select="false()"/>
        </xsl:variable>
        <xsl:for-each select="$tokens/tok">
            <xsl:if test="text() != 'active'">
                <tok is_active="{$is_active}">
                    <!-- Copy all the attributes of the context <tok> node. -->
                    <xsl:copy-of select="./@*"/>
                    <xsl:value-of select="."/>
                </tok>
            </xsl:if>
        </xsl:for-each>
    </xsl:function>

    <xsl:template name="lib:tpt_output_date" xmlns="urn:isbn:1-931666-33-4">
        <xsl:param name="tokens"/> 
        <!--
            Date determination logic is here, using the tokenized date. Some of this code is a bit
            dense. existDates must have same namespace as its parent element eac-cpf.
            
            We start of with several tests to determine dates that we cannot parse, and put them in a variable
            to neaten up the code and allow us to only have a single place where the unparsed date node set is
            constructed. Anything that makes it through these tests should be parse-able, although there is a
            catch-all otherwise at the end of the parsing choose.
            
            Forcing the data type of an attribute to be xs:boolean is probably not easy, so I didn't even
            try. Strong typing fails again.
        -->

        <xsl:variable name="is_active" as="xs:boolean">
                    <xsl:value-of select="true()"/>
        </xsl:variable>

        <xsl:if test="$debug">
            <xsl:message>
                <xsl:text>tokens: </xsl:text>
                <xsl:copy-of select="$tokens" />
                <xsl:text> isa: </xsl:text>
                <xsl:value-of select="($tokens/tok[1])/@is_active"/>
                <xsl:text> isf: </xsl:text>
                <xsl:value-of select="$is_active"/>
                <xsl:text>&#x0A;</xsl:text>
            </xsl:message>
        </xsl:if>

            <!--
                This is (perhaps) a bandaid for an extra "active" in is_family. We look for an active token
                and will not add literal text "active" if there is already and active token, even if is_family
                is true.
            -->
        <!-- <xsl:variable name="has_active" as="xs:boolean"> -->
        <!--     <xsl:choose> -->
        <!--         <xsl:when test="count($tokens/tok[matches(text(), 'active')]) = 0"> -->
        <!--             <xsl:value-of select="false()"/> -->
        <!--         </xsl:when> -->
        <!--         <xsl:otherwise> -->
        <!--             <xsl:value-of select="true()"/> -->
        <!--         </xsl:otherwise> -->
        <!--     </xsl:choose> -->
        <!-- </xsl:variable> -->

        <xsl:variable name="is_unparsed" as="xs:boolean">
            <xsl:choose>
                <!-- 
                     If there are no numeric tokens, the date is unparsed. Note
                     that since we only support integer values for years, we are
                     not checking all valid XML formats for numbers, only
                     [0-9]. Century numbers are a special case, so we have to
                     check them too.
                -->
                <!-- <xsl:when test="count($tokens/tok[matches(text(), '^\d+$|\d+.*century')]) = 0"> -->
                <xsl:when test="count($tokens/tok[text() = 'num']) = 0">
                    <xsl:value-of select="true()"/>
                </xsl:when>
                <!--
                    If there are two adjacent number tokens, then unparsed. Due to
                    the declarative nature of xpath, position() will be relative to
                    the context which will change as xpath iterates through the
                    first half of the xpath.
                -->
                <xsl:when test="$tokens/tok[text() = 'num']/following-sibling::tok[position()=1 and text() = 'num']">
                    <xsl:value-of select="true()"/>
                </xsl:when>

                <xsl:when test="$tokens/tok[text() = 'num' and string-length(text()) > 4]">
                    <xsl:value-of select="true()"/>
                </xsl:when>

                <!--
                    Alphabetic tokens that aren't our known list must be unparsed dates. Note that the second
                    regex matches against the full length of the token.
                -->
                <xsl:when test="$tokens/tok[matches(text(), '[A-Za-z]+') and
                                not(matches(text(), '^(num|approximately|or|active|century|b|d|st|nd|rd|th)$'))]">
                    <xsl:value-of select="true()"/>
                </xsl:when>
                <!--
                    Unrecognized tokens should only be year numbers. Any
                    supposed-year-numbers that are NAN or numbers > 2013 are errors
                    are unparsed dates. Also, notBefore and notAfter should never be
                    NaN.
                -->
                <xsl:when test="$tokens/tok[@notBefore='NaN' or
                                @notBefore='0' or
                                @notAfter='NaN' or
                                @notAfter='0' or
                                (not(matches(text(), '^(approximately|or|active|century|b|d|st|nd|rd|th|-)$')) and string(@std) = 'NaN') or
                                @std > $this_year or 
                                @std = 0 ]">
                    <xsl:value-of select="true()"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="false()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:choose>
            <!-- There is another unparsed "suspicious" date below in the otherwise element of this choose. -->
            <xsl:when test="$is_unparsed">
                    <date localType="{$av_suspiciousDate}">
                        <xsl:value-of select="$tokens/orig_date"/>
                    </date>
            </xsl:when>
        
            <!--
                This test may be meaningless now that numeric tokens have the value 'num'. Except for century,
                we don't like any token that mixes digits and non-digits. We also to not like strings of 5 or
                more digits.
            -->

            <xsl:when test="$tokens/tok[(matches(@std, '\d+[^\d]+|[^\d]+\d+') or matches(@std, '\d{5}')) and not(matches(@val, 'century'))]">
                    <date localType="{$av_suspiciousDate}">
                        <xsl:value-of select="$tokens/orig_date"/>
                    </date>
            </xsl:when>

            <!-- born -->

            <xsl:when test="$tokens/tok = 'b'  or (($tokens/tok)[last()] = '-')">
                <!-- No active since that is illogical with 'born' for persons. -->
                <xsl:variable name="loc_type">
                    <xsl:if test="$is_active">
                        <xsl:value-of select="$av_active"/>
                    </xsl:if>
                    <xsl:if test="not($is_active)">
                        <xsl:value-of select="$av_born"/>
                    </xsl:if>
                </xsl:variable>
                <xsl:variable name="curr_tok" select="$tokens/tok[text() = 'num'][1]"/>
                    <dateRange>
                        <fromDate>
                            <xsl:attribute name="standardDate" select="$curr_tok/@std"/>
                            <xsl:attribute name="localType" select="$loc_type"/>
                            <!-- Add attributes notBefore, notAfter.  -->
                            <xsl:for-each select="$curr_tok[text() = 'num'][1]/@*[matches(name(), '^not')]">
                                <xsl:choose>
                                    <xsl:when test="string-length(.)>0">
                                        <xsl:attribute name="{name()}">
                                            <xsl:value-of select="format-number(., '0000')"/>
                                        </xsl:attribute>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:message>
                                            <xsl:text>fromDate empty attr: </xsl:text>
                                            <xsl:copy-of select="." />
                                        </xsl:message>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:for-each>
                            

                            <!--
                                We know this is a birth date so make that clear in the human readable part of
                                the date by putting a '-' (hyphen, dash) after the date.
                                
                                Put @sep in. If it is blank that's fine, but if not blank, we need it.
                            -->
                            <!-- all tokens before the first date, this includes things like "approximately" -->
                            <xsl:for-each select="$tokens/tok[text() = 'num'][1]/preceding-sibling::tok">
                                <xsl:choose>
                                    <xsl:when test="text() = 'b' or text() = '-'">
                                        <!-- Skip. We already added human readable "born" above. -->
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="concat(., ' ')"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:for-each>

                            <xsl:value-of select="normalize-space(concat($curr_tok/@val, $curr_tok/@sep))"/>

                        </fromDate>
                        <toDate/>
                    </dateRange>
            </xsl:when>
            
            <!-- died --> 
            <xsl:when test="($tokens/tok = 'd') or ($tokens/tok[1] = '-')">
                <!--
                    No active since that is illogical with 'died', unless $is_family/$is_active in which case this is "active" and not "died".
                -->
                <xsl:variable name="loc_type">
                    <xsl:choose>
                        <xsl:when test="$is_active">
                            <xsl:value-of select="$av_active"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$av_died"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="curr_tok" select="$tokens/tok[text() = 'num'][1]"/>
                    <dateRange>
                        <fromDate/>
                        <toDate>
                            <xsl:attribute name="standardDate" select="$curr_tok/@std"/>
                            <xsl:attribute name="localType" select="$loc_type"/>
                            <!-- Add attributes notBefore, notAfter.  -->
                            <xsl:for-each select="$curr_tok/@*[matches(name(), '^not')]">
                                <xsl:attribute name="{name()}">
                                    <xsl:value-of select="format-number(., '0000')"/>
                                </xsl:attribute>
                            </xsl:for-each>

                            <!-- all tokens before the first date, this includes things like "approximately" -->
                            <xsl:for-each select="$tokens/tok[text() = 'num'][1]/preceding-sibling::tok">
                                <xsl:choose>
                                    <xsl:when test="text() = 'd' or text() = '-'">
                                        <!-- Skip. We already added human readable "died" above. -->
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="concat(., ' ')"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:for-each>
                            
                            <xsl:value-of select="normalize-space(concat($curr_tok/@val, ' ', $curr_tok/@sep))"/>
                        </toDate>
                    </dateRange>
            </xsl:when>

            <xsl:when test="count($tokens/tok[text() = '-']) > 0 and count($tokens/tok[text() = 'num']) > 1">
                <!--
                    We have a hyphen and two numbers so it must be from-to.
                -->
                    <dateRange>
                        <fromDate>
                            <xsl:variable name="curr_tok" select="$tokens/tok[text() = 'num'][1]"/>
                            <xsl:variable name="is_century" select="$curr_tok[matches(@val, 'century')]"/>
                            <xsl:attribute name="standardDate" select="$curr_tok/@std"/>
                            <!--
                                Old: If we have an 'active' token before the hyphen, then then make the subject 'active'.
                                
                                New: if we're active then we're active. There are no more tokens "active",
                                only an attribute on every <tok> @is_active and thus the local variable
                                $is_active.
                            -->
                            <xsl:choose>
                                <!-- <xsl:when test="($tokens/tok[text() = '-']/preceding-sibling::tok = 'active') or $is_active or $is_century"> -->
                                <xsl:when test="$is_active or $is_century">
                                    <xsl:attribute name="localType">
                                        <xsl:value-of select="$av_active"/>
                                    </xsl:attribute>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:attribute name="localType">
                                        <xsl:value-of select="$av_born"/>
                                    </xsl:attribute>
                                </xsl:otherwise>
                            </xsl:choose>

                            <!-- Add attributes notBefore, notAfter.  -->
                            <xsl:for-each select="$curr_tok/@*[matches(name(), '^not')]">
                                <xsl:attribute name="{name()}">
                                    <xsl:value-of select="format-number(., '0000')"/>
                                </xsl:attribute>
                            </xsl:for-each>

                            <!-- Text of all tokens before the first date such as "active", "approximately". -->
                            <xsl:for-each select="$tokens/tok[text() = 'num'][1]/preceding-sibling::tok">
                                <xsl:value-of select="concat(., ' ')"/>
                            </xsl:for-each>
                            
                            <xsl:value-of select="concat($curr_tok/@val, $curr_tok/@sep)"/>
                        </fromDate>

                        <toDate>
                            <xsl:variable name="curr_tok" select="$tokens/tok[text() = 'num'][2]"/>
                            <xsl:variable name="is_century" select="$curr_tok[matches(@val, 'century')]"/>
                            <xsl:attribute name="standardDate" select="$curr_tok/@std"/>
                            <!--
                                Old: if we have an 'active' token anywhere  or $is_family then 'active' else 'died'
                                
                                New: if we're active then we're active. There are no more tokens "active",
                                only an attribute on every <tok> @is_active and thus the local variable
                                $is_active.
                            -->
                            <xsl:choose>
                                <!-- <xsl:when test="($tokens/tok[text() = 'active']) or $is_family or $is_century"> -->
                                <xsl:when test="$is_active or $is_century">
                                    <xsl:attribute name="localType">
                                        <xsl:value-of select="$av_active"/>
                                    </xsl:attribute>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:attribute name="localType">
                                        <xsl:value-of select="$av_died"/>
                                    </xsl:attribute>
                                </xsl:otherwise>
                            </xsl:choose>

                            <!-- Add attributes notBefore, notAfter.  -->
                            <xsl:for-each select="$curr_tok/@*[matches(name(), '^not')]">
                                <xsl:attribute name="{name()}">
                                    <xsl:value-of select="format-number(., '0000')"/>
                                </xsl:attribute>
                            </xsl:for-each>

                            <xsl:value-of select="$curr_tok/@val"/>

                            <xsl:for-each select="$tokens/tok[matches(text(), '-')]/following-sibling::tok">
                                <xsl:value-of select="@sep"/>
                                <xsl:if test="not(text() = 'num')">
                                    <xsl:text> </xsl:text>
                                </xsl:if>
                                <!-- no @sep or active here. It would look odd to humans. -->
                            </xsl:for-each>
                        </toDate>
                    </dateRange>
            </xsl:when>

            <xsl:when test="count($tokens/tok[text() = '-']) = 0 and count($tokens/tok[text() = 'num']) = 1">
                <!--
                    No hyphen and only one number so this is a single date.  New: active is active. Old: If we
                    have an 'active' token then $av_active.
                -->
                <xsl:variable name="curr_tok" select="$tokens/tok[text() = 'num']"/>
                    <date>
                        <xsl:attribute name="standardDate" select="$curr_tok/@std"/>
                        <!-- <xsl:if test="($tokens/tok[text() = 'active']) or $is_family"> -->
                        <xsl:if test="$is_active">
                            <xsl:attribute name="localType">
                                <xsl:value-of select="$av_active"/>
                            </xsl:attribute>
                        </xsl:if>

                        <!-- Add attributes notBefore, notAfter.  -->
                        <xsl:for-each select="$curr_tok/@*[matches(name(), '^not')]">
                            <xsl:choose>
                                <xsl:when test="string-length(.)>0">
                                    <xsl:attribute name="{name()}">
                                        <xsl:value-of select="format-number(., '0000')"/>
                                    </xsl:attribute>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:message>
                                        <xsl:text>date empty attr: </xsl:text>
                                        <xsl:copy-of select="." />
                                        <xsl:text>&#x0A;</xsl:text>
                                        <xsl:copy-of select="$tokens" />
                                    </xsl:message>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each>

                        <!-- the date itself, with @sep. -->
			<xsl:value-of select="$tokens/orig_date" />

                    </date>
            </xsl:when>

            <xsl:otherwise>
                    <date localType="{$av_suspiciousDate}">
                        <xsl:value-of select="$tokens/orig_date"/>
                    </date>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template> <!-- end tpt_show_date -->

    <xsl:function name="lib:date_cat" as="xs:string" >
        <xsl:param name="date" as="xs:string?"/> 
        <xsl:param name="cat" as="xs:string?"/> 
        <xsl:sequence select="concat(substring($date, 1, string-length($date) - string-length($cat)), $cat)"/>
    </xsl:function>


    <xsl:function name="lib:ordinal_number">
        <xsl:param name="date" as="xs:string?"/>
        <!--
            Get the digits from 1st 2nd 3rd 4th, etc. Must have an outer element
            or xpath for the inner elements is tricky. For input "20th" output
            is <ord><num>20</num><suffix>th</suffix></ord>.
        -->
        <xsl:analyze-string select="$date" regex="(\d+)(.*)">
            <xsl:matching-substring>
                <xsl:element name="ord">
                    <xsl:element name="num">
                        <xsl:value-of select="regex-group(1)"/>
                    </xsl:element>
                    <xsl:element name="suffix">
                        <xsl:value-of select="regex-group(2)"/>
                    </xsl:element>
                </xsl:element>
            </xsl:matching-substring>
        </xsl:analyze-string>
    </xsl:function>


    <xsl:function name="lib:min_ess" as="xs:integer">
        <xsl:param name="date"/>
        <!--
            Return the minimum number for 1800s. This is trivial now, but it
            seems like it might need future complexity, so it is here in a
            function. Companion to max_ess() below.
        -->
        <xsl:value-of select="$date"/>
    </xsl:function>


    <xsl:function name="lib:max_ess" as="xs:integer">
        <xsl:param name="date"/>
        <!--
            Return the max number for 1800s. For now we only handle 100s or 10s, for example 1800s or
            1820s. Companion to min_ess() above. Returning zero upon failure is dubious, and I don't think it
            will ever happen. Saxon 8 didn't care, but 9he knows when there's no xsl:otherwise.
        -->
        <xsl:choose>
            <xsl:when test="(number($date) mod 100) = 0">
                <xsl:value-of select="number($date) + 99"/>
            </xsl:when>
            <xsl:when test="(number($date) mod 10) = 0">
                <xsl:value-of select="number($date) + 9"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>0</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

</xsl:stylesheet>
