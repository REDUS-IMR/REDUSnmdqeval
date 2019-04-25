<!--
         When a file is transformed using this stylesheet the output will be
    formatted as follows:

    ** Pass #1 / ignore **
    1.)  Elements named "info" will be removed
    2.)  Attributes named "file_line_nr" or "file_name" will be removed
    3.)  Comments will be removed
    4.)  Processing instructions will be removed
    5.)  XML declaration will be removed
    6.)  Extra whitespace will be removed
    7.)  Empty attributes will be removed
    8.)  Elements which have no attributes, child elements, or text will be removed

    ** Pass #2 / sortAttributes **
    9.) All attributes will be sorted by name

    ** Pass #3 & #4 / sortElements **
    10.)  All elements will be sorted by name and their contents recursively

    ** Pass #5 / deDup **
    11.)  Duplicate sibling elements will be removed
-->
<xsl:stylesheet version="2.0" xmlns:custom="custom:custom" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <!-- Set output options -->
    <xsl:output indent="yes" method="xml" omit-xml-declaration="yes"/>
    <xsl:strip-space elements="*"/>

<!--****************************************************************************

Mode templates

*****************************************************************************-->

    <xsl:template match="/">
        <!-- First pass with ignore mode templates -->
        <xsl:variable name="ignoreRslt">
            <xsl:apply-templates mode="ignore"/>
        </xsl:variable>

        <!-- Second pass with sortAttributes mode templates -->
        <xsl:variable name="sortAttributesRslt">
            <xsl:apply-templates mode="sortAttributes" select="$ignoreRslt"/>
        </xsl:variable>

        <!-- Third pass with sortElements mode templates -->
        <xsl:variable name="sortElementsRslt1">
            <xsl:apply-templates mode="sortElements" select="$sortAttributesRslt"/>
        </xsl:variable>

        <!-- Fourth pass with sortElements mode templates -->
        <xsl:variable name="sortElementsRslt2">
            <xsl:apply-templates mode="sortElements" select="$sortElementsRslt1"/>
        </xsl:variable>

        <!-- Fifth pass with deDup mode templates -->
        <xsl:apply-templates mode="deDup" select="$sortElementsRslt2"/>
    </xsl:template>

<!--****************************************************************************

Pass #1 / ignore mode templates

*****************************************************************************-->

    <!-- Elements/attributes to ignore -->
    <xsl:template match="@*[normalize-space()='']|*:nation|*:report_time|*[not(@*|node())]" mode="ignore"/>

    <!-- Match any attribute or element -->
    <xsl:template match="@*|*" mode="ignore">
        <xsl:copy>
            <xsl:apply-templates mode="ignore" select="@*"/>
            <xsl:apply-templates mode="ignore"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="@*[local-name(.)='noNamespaceSchemaLocation']"/>
<!--****************************************************************************

Pass #2 / sortAttributes mode templates

*****************************************************************************-->

    <!-- Match any attribute or element -->
    <xsl:template match="@*|*" mode="sortAttributes">
        <xsl:copy>
            <xsl:apply-templates mode="sortAttributes" select="@*">
                <xsl:sort select="name()"/>
            </xsl:apply-templates>
            <xsl:apply-templates mode="sortAttributes"/>
        </xsl:copy>
    </xsl:template>

<!--****************************************************************************

Pass #3 & #4 / sortElements mode templates

*****************************************************************************-->

    <!-- Match any attribute or element -->
    <xsl:template match="@*|*" mode="sortElements">
        <xsl:copy>
            <xsl:apply-templates mode="sortElements" select="@*"/>
            <xsl:apply-templates mode="sortElements">
                <xsl:sort select="name()"/>
                <xsl:sort select="custom:sortElementsByAttrNameAndVal(.)"/>
                <xsl:sort select="."/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>

<!--****************************************************************************

Pass #5 / deDup mode templates

*****************************************************************************-->

    <!-- Match any element -->
    <xsl:template match="@*|node()" mode="deDup">
        <xsl:copy>
            <xsl:apply-templates mode="deDup" select="@*|node()"/>
        </xsl:copy>
    </xsl:template>

    <!-- Ignore elements which are deep-equal to a preceding sibling element -->
    <xsl:template match="*[some $ps in preceding-sibling::* satisfies deep-equal(.,$ps)]" mode="deDup"/>

<!--****************************************************************************

sortElementsByAttrNameAndVal

*****************************************************************************-->

    <!-- Function to sort elements by attribute name and value -->
    <xsl:function name="custom:sortElementsByAttrNameAndVal" as="xs:string">
        <xsl:param name="aNode" as="node()"/>
        <xsl:variable name="sequenceFragments">
            <xsl:for-each select="$aNode/@*">
                <xsl:sort select="name()"/>
                <xsl:value-of select="concat(name(),'+',.)"/>
            </xsl:for-each>
            <xsl:text>|</xsl:text>
        </xsl:variable>
        <xsl:sequence select="string-join($sequenceFragments,'')"/>
    </xsl:function>

</xsl:stylesheet>

