#!/bin/bash
# v=0.1
# References 1 http://software.es.net/maddash/api_intro.html
#            2 https://psetf.grid.iu.edu/etf/check_mk/index.py?start_url=%2Fetf%2Fcheck_mk%2Fview.py%3Fhost%3Dperfsonar1.ihepa.ufl.edu%26site%3Detf%26view_name%3Dhost
# START of Local Configuration
workdir=/raid/raid9/bockjoo/T2/ops/ftools/ftools/ftool_check_perfsonar # the directory where this script is running
notifytowhom=bockjoo@phys.ufl.edu # @ @ @ @ @ @ @ @ @ @ # the ones that need to be notified about isues on $MYSITE
MYSITE=Florida #  FNAL MIT Florida Caltech Sprace Nebraska Purdue UCSD Wisconsin Vanderbilt
webroot=$HOME/services/external/apache2/htdocs # The web page root directory
webdir=${webroot}/t2 # The location wehere one can actively view the status if there is a web server
# Download webisoget (for check_mk single sign on) from somewhere ( google it ) and build it first
export PATH=${PATH}:/softraid/bockjoo/T2/ops/ftools/webisoget-2.8.4/bin # webisoget binary direcotry
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/softraid/bockjoo/T2/ops/ftools/webisoget-2.8.4/lib # webisoget shared lib directory
CACHE=$HOME/webisoget.cache # webisoget cache file
# END of Local Configuratoin
# How to create myCert.pem -key and $HOME/.cmssoft/myCert.key? Use the following script (L22 - L27)
# References
# [1] http://linux.web.cern.ch/linux/docs/cernssocookie.shtml
# [2] http://linuxsoft.cern.ch/cern/slc6X/x86_64/yum/extras/repoview/cern-get-sso-cookie.html
# [3] http://linuxsoft.cern.ch/cern/slc6X/x86_64/yum/extras/
if [ -f myCert.p12 ] ; then  
  openssl pkcs12 -clcerts -nokeys -in myCert.p12 -out $HOME/.cmssoft/myCert.pem # L22
  openssl pkcs12 -nocerts -in myCert.p12 -out $HOME/.cmssoft/myCert.tmp.key
  openssl rsa -in ~/private/myCert.tmp.key -out $HOME/.cmssoft/myCert.key
  rm $HOME/.cmssoft/myCert.tmp.key
  chmod 644 $HOME/.cmssoft/myCert.pem
  chmod 400 $HOME/.cmssoft/myCert.key #L27
fi

dashboard=http://psmad.grid.iu.edu
dashboard_gui="http://psmad.grid.iu.edu/maddash-webui/details.cgi?uri="
hostlist=$workdir/hostlist.txt
#check_mk_detail=https://psetf.grid.iu.edu/etf/check_mk/view.py?host=${h}&output_format=csv_export&selection=5e86d4b6-755f-47de-965a-8f2fc592328c&service=perfSONAR%20configuration%3A%20contacts&site=etf&view_name=service
#check_mk_detail="https://psetf.grid.iu.edu/etf/check_mk/index.py?start_url=%2Fetf%2Fcheck_mk%2Fview.py%3Fhost%3D\${h}%26service%3D\${service}%253A%2520contacts%26site%3Detf%26view_name%3Dservice"
#https://psetf.grid.iu.edu/etf/check_mk/index.py?start_url=%2Fetf%2Fcheck_mk%2Fview.py%3Fhost%3Dperfsonar1.ihepa.ufl.edu%26service%3DperfSONAR%2520configuration%253A%2520contacts%26site%3Detf%26view_name%3Dservice
check_mk_detail="https://psetf.grid.iu.edu/etf/check_mk/view.py?host=\${h}&service=\${service}&site=etf&view_name=service"

check_perfsonar_version=0.1

function monitor_status_color () {
  status=$1
  color=
  [ $1 == OK ] && color=green
  [ $1 == WARN ] && color=yellow
  [ $1 == CRIT ] && color=red
  [ $1 == UNKN ] && color=grey
  [ "x$color" == "x" ] && color=black
  echo $color
}

function sites () {
  for s in FNAL MIT Florida Caltech Sprace Nebraska Purdue UCSD Wisconsin Vanderbilt ; do echo $s ; done
}

function thesite_to_site () {
  for s in FNAL MIT Florida Caltech Sprace Nebraska Purdue UCSD Wisconsin Vanderbilt ; do
     echo "$1" | grep -q -i $s
     [ $? -eq 0 ] && { echo $s ; return 0 ; } ; 
  done
  echo Unknown
}


function create_checked_metrics () {

  uscms_maddash_grids=$(wget -q -O- ${dashboard}/maddash/dashboards | sed "s#{\"name#\n{\"name#g"  | grep USCMS | sed "s#\"uri\":#\n\"uri\":#g" | grep uri | cut -d\" -f4 | cut -d/ -f4)
  for g in $uscms_maddash_grids ; do echo $g ; done | grep "USCMS+Latency\|USCMS+Bandwidth"
  grids=$(for g in $uscms_maddash_grids ; do echo $g ; done | grep "USCMS+Latency\|USCMS+Bandwidth")
  i=0
  for g in $grids ; do
      i=$(expr $i + 1)
      echo "[$i]" grid=$g
      #[ ! -s $workdir/grid_equal_${g}_rows.txt -o "x$(date +%M)" == "x42" ] && wget -q -O- ${dashboard}/maddash/grids/$g | sed "s#\"rows\":#\n\"rows\":#g"  | grep rows | sed "s#{\"name#\n{\"name#g" | grep "{\"name\"" | grep name | grep uri | cut -d\" -f4 > $workdir/grid_equal_${g}_rows.txt
      #[ ! -s $workdir/grid_equal_${g}_rows.txt -o "x$(date +%M)" == "x42" ] && wget -q -O- ${dashboard}/maddash/grids/$g | sed "s#\"rows\":#\n\"rows\":#g"  | grep rows | sed "s#\"uri#\n\"uri#g" | grep uri | cut -d\" -f4 > $workdir/grid_equal_${g}_rows.txt
      wget -q -O- ${dashboard}/maddash/grids/$g | sed "s#\"rows\":#\n\"rows\":#g"  | grep rows | sed "s#\"uri#\n\"uri#g" | grep uri | cut -d\" -f4 > $workdir/grid_equal_${g}_rows.txt
      #while read row ; do
      #    echo wget -q -O- "${dashboard}/maddash/grids/$g/${row}"
      #done < $workdir/grid_equal_${g}_rows.txt 
      for row in $(cat $workdir/grid_equal_${g}_rows.txt | cut -d/ -f5 ) ; do
          uri=${dashboard}/maddash/grids/${g}/$row
          #[ ! -s $workdir/grid_equal_${g}_${row}_cells.txt -o "x$(date +%M)" == "x42" ] && wget -q -O- $uri | sed "s#\"cells\":#\n\"cells\":#g"  | grep cells  | sed "s#\"uri#\n\"uri#g" | grep uri | cut -d\" -f4 > $workdir/grid_equal_${g}_${row}_cells.txt
          wget -q -O- $uri | sed "s#\"cells\":#\n\"cells\":#g"  | grep cells  | sed "s#\"uri#\n\"uri#g" | grep uri | cut -d\" -f4 > $workdir/grid_equal_${g}_${row}_cells.txt
          #echo $workdir/grid_equal_${g}_${row}_cells.txt
          #break
          for cell in $(cat $workdir/grid_equal_${g}_${row}_cells.txt | cut -d/ -f6 ) ; do
              uri=${dashboard}/maddash/grids/${g}/$row/${cell}
              wget -q -O- $uri | sed "s#\"checks\":#\n\"checks\":#g"  | grep checks | sed "s#\"uri#\n\"uri#g" | grep uri | cut -d\" -f4 > $workdir/grid_equal_${g}_${row}_${cell}_checks.txt
              #echo $workdir/grid_equal_${g}_${row}_${cell}_checks.txt
              #break
              #LOSS_OR_TPS=""
              for check in $(cat $workdir/grid_equal_${g}_${row}_${cell}_checks.txt | cut -d/ -f7 ) ; do
                  uri=${dashboard}/maddash/grids/${g}/$row/${cell}/"${check}"
                  #echo DEBUG 1 uri=$uri
                  #echo DEBUG 0 uri=${dashboard}/maddash/grids/USCMS+Mesh+Config+-+USCMS+Latency+Mesh+Test/perfsonar2.ultralight.org/perfsonar-cms1.itns.purdue.edu/Loss
                  wget -q -O- $uri > $workdir/grid_equal+${g}+${row}+${cell}+${check}+content.txt #| sed "s#\"checks\":#\n\"checks\":#g"  | grep checks | sed "s#\"uri#\n\"uri#g" | grep uri | cut -d\" -f4 > $workdir/grid_equal_${g}_${row}_${cell}_${check}_.txt
                  #echo $workdir/grid_equal+${g}+${row}+${cell}+${check}+content.txt
                  LOSS_OR_TP=$(cat $workdir/grid_equal+${g}+${row}+${cell}+${check}+content.txt | sed "s#\"message\"#\n\"message\"#g" | grep \"message\" | head -1 | cut -d\" -f4 | grep "Average throughput is\|Average Loss is" | sed "#Average throughput is##g" | sed "s#Average Loss is##g")
                  echo $LOSS_OR_TP > $workdir/grid_equal+${g}+${row}+${cell}+${check}+content.txt
                  #echo "$row $cell $check" $(cat $workdir/grid_equal+${g}+${row}+${cell}+${check}+content.txt | sed "s#\"message\"#\n\"message\"#g" | grep \"message\" | head -1 | cut -d\" -f4 | grep "Average throughput is\|Average Loss is")
                  #break
             done
             #break
          done
          #break
      done
      
      #for c in $(cat  $workdir/grid_equal_${g}_${row}_${cell}_checks.txt) ; do
      #    :
      #done
  done
}

#list_cells


#create_checked_metrics

#exit 0
# at least once a day it should be updated in case there is a change in the host list
MEET_HOUR=14
#echo DEBUG -s $hostlist -o "x$(date +%H)" == "x${MEET_HOUR}"
if [ ! -s $hostlist -o "x$(date +%H)" == "x${MEET_HOUR}" ] ; then
  #wget -q -O- http://psmad.grid.iu.edu/maddash/dashboards | sed "s#{\"name#\n{\"name#g"  | grep USCMS | grep uri
  uscms_maddash_grids=$(wget -q -O- ${dashboard}/maddash/dashboards | sed "s#{\"name#\n{\"name#g"  | grep USCMS | sed "s#\"uri\":#\n\"uri\":#g" | grep uri | cut -d\" -f4 | cut -d/ -f4)
  grids=$(for g in $uscms_maddash_grids ; do echo $g ; done | grep "USCMS+Latency\|USCMS+Bandwidth") # only IPv4 for now
  #for g in $grids ; do echo wget -q -O- ${dashboard}/maddash/grids/$g ; done
  for g in $grids ; do
     host_sites=$(wget -q -O- ${dashboard}/maddash/grids/$g | sed "s#{\"message#\n{\"message#g" | sed "s#\"rows\":#\n\"rows\":#g"  | sed "s#\"name\":#\n\"name\":#g" | grep ^\"name\" | grep uri | cut -d\" -f4,8 | sed "s# ##g" | sed 's#"# #' | awk '{print $2"|"$1}' | cut -d/ -f5)
     for hs in $host_sites ; do echo ${hs}"|"${g} ; done
  done > $hostlist
else
  echo INFO $hostlist exists or it is not ${MEET_HOUR} HOUR.
fi
hosts=$(cat $hostlist)
tlds=$(for h in $hosts ; do echo $h | cut -d\| -f1 ; done | sed "s#\.# #g" | awk '{print $(NF-1)" "$NF}' | sort -u | awk '{print $(NF-1)"."$NF}' )
#echo $hosts
#for h in $hosts ; do echo $h ; done
#exit 0
webout=$HOME/services/external/apache2/htdocs/T2/ops/USCMS_PerfSonar_Unmeshed.html
#/bin/cp $webout $webout.0
#/bin/cp /dev/null $webout
colspan=1
echo "<html>" > ${webout}.0
echo "<h1><FONT color='green'>Simple Monitoring for the USCMS Perfsonars</FONT></h1>" >> ${webout}.0
echo "<h1>Updated at $(date). Next Update: 1 Hour later </h1>" >> ${webout}.0
echo "<h1>References: <a href='https://psetf.grid.iu.edu/etf/check_mk/' target=_blank>Check_MK</a> &nbsp;&nbsp <a href='http://software.es.net/maddash/api_intro.html'  target=_blank>Maddash API Intro</a>  &nbsp;&nbsp <a href='http://psmad.grid.iu.edu/maddash-webui/index.cgi?dashboard=USCMS%20Mesh%20Config'  target=_blank>USCMS Maddash</a><h1>"  >> ${webout}.0

echo "<h1>Docs for Installation/Configuration/Debugging: </h1>" >> ${webout}.0

echo "<h1><a href='https://opensciencegrid.github.io/networking/' target=_blank>OSG Documentation</a> &nbsp;&nbsp <a href='http://docs.perfsonar.net/config_files.html'  target=_blank>List of Perfsonar Logs</a>&nbsp;&nbsp;<a href=\"https://github.com/perfsonar/pscheduler/wiki/CLI-User's-Guide\" target=_blank> pScheduler CLI</a></h1>"  >> ${webout}.0

echo "<h1>Links for Analytics </h1>" >> ${webout}.0

echo "<h1><a href=\"http://atlas-kibana.mwt2.org:5601/app/kibana#/discover?_g=(refreshInterval:(display:Off,pause:!f,value:0),time:(from:now%2Fd,mode:quick,to:now%2Fd))&_a=(columns:!(src_site,dest_site,'throughput%20%5BGbps%5D',timestamp),index:'267cb400-005f-11e8-8f2f-ab6704660c79',interval:auto,query:(language:lucene,query:''),sort:!(timestamp,desc))\" target=_blank> ThroughPut </a>" >> ${webout}.0

echo "[ <FONT color='black'> &#x2192; </FONT> ] &nbsp; &nbsp; <FONT color='red'>Latency Loss row unit is either milli % or %</FONT>" >> ${webout}.0

echo "<table>" >> ${webout}.0
for tld in $tlds ; do
   hs=$(for h in $hosts ; do echo $h | cut -d\| -f1 ; done | grep $tld)  
   for h in $hs ; do
      #[ ! -s $workdir/$h.html -o "x$(date +%M)" == "x42" ] &&
      webisoget -cache $CACHE -form "name=hiddenform" -cert $HOME/.cmssoft/myCert.pem -key $HOME/.cmssoft/myCert.key -out $workdir/$h.html -url "https://psetf.grid.iu.edu/etf/check_mk/view.py?host=${h}&output_format=csv_export&site=etf&view_name=host"
      # wc -l $workdir/$h.html
      [ $(cat $workdir/$h.html | wc -l) -gt $colspan ] && colspan=$(cat $workdir/$h.html | wc -l)
   done
done
#echo DEBUG colspan=$colspan
colspan_unmeshed=$(sites | wc -w)
totalcol=$(expr $colspan + $colspan_unmeshed)
echo "<tr bgcolor='cyan'><td rowspan=2>Site LAT/BW &#x2192;</td><td rowspan=2 colspan='$colspan' width=200>Check MK Status</td><td colspan='$colspan_unmeshed'>LT/BW Destination Site</td></tr>" >>  ${webout}.0
echo "<tr bgcolor='cyan'><td>FNAL</td><td>MIT</td><td>SPRACE</td><td>Purdue</td><td>UCSD</td><td>Florida</td><td>CALTECH</td><td>Nebraska</td><td>Vanderbilt</td><td>Wisconsin</td></tr>" >>  ${webout}.0
#for tld in $tlds ; do echo $tld ; done
#echo DEBUG "x$(date +%M)" == "x42"
echo INFO creating simplified mesh... "(for now disable for development)"
create_checked_metrics
#for hst in $hosts ; do echo $hst ; done
#exit 0
NOTOKLOSS=0
NOTOKTPUT=0
NOTOKTPUTA=0
CNOTOKLOSS=0
CNOTOKTPUT=0
CNOTOKTPUTA=0
for tld in $tlds ; do
   hs=$(for h in $hosts ; do echo $h | cut -d\| -f1 ; done | grep $tld)
   
   #for h in $hs ; do
   #   [ ! -s $workdir/$h.html -o "x$(date +%M)" == "x42" ] && webisoget -cache $CACHE -form "name=hiddenform" -cert $HOME/.cmssoft/myCert.pem -key $HOME/.cmssoft/myCert.key -out $workdir/$h.html -url "https://psetf.grid.iu.edu/etf/check_mk/view.py?host=${h}&output_format=csv_export&site=etf&view_name=host"
   #done
   rowspan=$(echo $hs | wc -w)
   
   for shost in $hs ; do
      irow=$(expr $irow + 1)
      #for hst in $hosts ; do echo $hst ; done
      g=$(for hst in $hosts ; do echo $hst ; done | grep $shost | cut -d\| -f3)
      thesite=$(for hst in $hosts ; do echo $hst ; done | grep $shost | cut -d\| -f2)
      site=$(thesite_to_site "$thesite")
      stati=$(grep $shost $workdir/${shost}.html | cut -d\" -f4)
      col=$(cat $workdir/${shost}.html | wc -l)
      #status=$(grep $h $workdir/$h.html | cut -d\" -f4 | sed "s#^#+#g")
      #status=$(echo $status | sed "s#+##")
      echo grid=$g site=$site stati=$stati
      grep $shost $workdir/${shost}.html | cut -d\" -f4 | cut -c1 | grep -q "C\|U"
      if [ $? -eq 0 ] ; then
         echo $site | grep -q $MYSITE
         if [ $? -eq 0 ] ; then
            printf "$(basename $0) $(/bin/hostname) Perfsonar in critical or unknown status\n$(cat $workdir/${shost}.html | sed 's#%#%%#g')\n" | mail -s "ERROR perfsonar" $notifytowhom        
         fi
      fi
      THETD=""
      ic=0
      for status in $stati ; do
          ic=$(expr $ic + 1)
          thestatus=$(echo $status | cut -c1)
          #echo DEBUG "[ $ic } " service=$(grep "$h" $workdir/$h.html | head -${ic} | tail -1 | cut -d\" -f6)
          service=$(grep "${shost}" $workdir/${shost}.html | head -${ic} | tail -1 | cut -d\" -f6)
          check_mk_detail="https://psetf.grid.iu.edu/etf/check_mk/view.py?host=${shost}&service=${service}&site=etf&view_name=service"
          
          thestatus="<a href='$check_mk_detail' target=_blank> $thestatus </a>"
          color=$(monitor_status_color $status)
          if [ $col -lt $colspan ] ; then
             if [ $ic -eq $col ] ; then
                thecol=$(expr $colspan - $col + 1)
                THETD="$THETD <td colspan='$thecol' bgcolor='$color'> $thestatus </td>"
             else
                THETD="$THETD <td bgcolor='$color'>$thestatus </td>"
             fi
          else
             THETD="$THETD <td bgcolor='$color'>$thestatus </td>"
          fi 
      done
      #echo DEBUG THETD=$THETD
      ncol=$(echo $THETD | sed "s#<td#\n<td#g" | grep "<td" | wc -l)
      THCON=""
      #check_previous=
      irow=0
      if=0
      #for tldd in $tlds ; do hsd=$(for hd in $hosts ; do echo $hd | cut -d\| -f1 ; done | grep $tldd)
      #ntest=$(ls $workdir/grid_equal+${g}+${h}+*+content.txt 2>/dev/null | sort -u | wc -l)
      checks=$(for f in $(ls $workdir/grid_equal+${g}+${shost}+*+content.txt 2>/dev/null | sort -ru) ; do echo $f | sed "s#${shost}# #" | awk '{print $NF}' | cut -d+ -f3- ; done | sort -u)
      for ck in $checks ; do
          irow=$(expr $irow + 1)
          # create an artificial file for same site mesh
          #echo DEBUG same site mesh : $workdir/grid_equal+${g}+${shost}+${shost}+${ck}
          [ -f $workdir/grid_equal+${g}+${shost}+${shost}+${ck} ] || touch $workdir/grid_equal+${g}+${shost}+${shost}+${ck}
          ntest=$(ls $workdir/grid_equal+${g}+${shost}+*+content.txt 2>/dev/null | sort -u | grep $ck |  wc -l)
          #ntest=$(expr $ntest + 1) # site-site 
          #itldd=0
          #for tldd in $tlds ; do
          #   itldd=$(expr $itldd + 1)
          #   echo DEBUG "[$itldd]" tldd=$tldd fls=$workdir/grid_equal+${g}+${shost}+\*+content.txt ck=$ck
          #                  for f in $(ls $workdir/grid_equal+${g}+${shost}+*+content.txt 2>/dev/null | sort -ru | grep $ck) ; do
          #                    destination=$(echo $f | sed "s#{shost}#${shost} #" | awk '{print $NF}')
          #                    echo DEBUG "[itldd=$itldd]" destination=$destination f=$f
          #                    echo $destination | grep -q $tldd
          #                    [ $? -eq 0 ] && { echo "[itldd=$itldd]" f=$f ; break ; } ;
          #                  done
          #                done
          ordered_files=$(for tldd in $tlds ; do
                            for f in $(ls $workdir/grid_equal+${g}+${shost}+*+content.txt 2>/dev/null | sort -ru | grep $ck) ; do
                              destination=$(echo $f | sed "s#${shost}#${shost} #" | awk '{print $NF}')
                              echo $destination | grep -q $tldd
                              [ $? -eq 0 ] && { echo $f ; break ; } ;
                            done
                          done)
      #echo DEBUG ordered_files=$(echo $ordered_files | wc -w) ntest=$ntest
      #iord=0
      #for f in $ordered_files ; do
      #    iord=$(expr $iord + 1)
      #    echo DEBUG "[$iord]" checking if file is ordered $f
      #done
      #for f in $(ls $workdir/grid_equal+${g}+${h}+*+content.txt 2>/dev/null | sort -ru | grep $ck) ; do # $workdir/grid_equal+${g}+${row}+${cell}+${check}+content.txt
      for f in $ordered_files ; do
          cell=$(echo $f | sed "s#${shost}# #" | awk '{print $NF}' | cut -d+ -f2)
          thesite_cell=$(for hst in $hosts ; do echo $hst ; done | grep $cell | cut -d\| -f2)
          site_cell=$(thesite_to_site "$thesite_cell")

          #echo $cell | grep -q "$tldd"
          #[ $? -eq 0 ] || continue
          if=$(expr $if + 1)
          #[ "x$f" == "x$workdir/grid_equal+${g}+${h}+*+content.txt" ] && continue
          check=$(echo $f | sed "s#${shost}# #" | awk '{print $NF}' | cut -d+ -f3- | sed "s#+content\.txt##")
          content=$(echo $(cat $f | sed "s#100.000%#100.0%#g" | sed "s#Average throughput is ##g" | sed "s#Gbps#G#g"))
          echo "$content" | grep -q G ; [ $? -eq 0 ] && { content=$(echo $content | cut -d. -f1)"."$(echo $content | sed "s#\.# #" | awk '{print $NF}' | cut -c1)"G" ; } ; # keep only the first decimal place
          color=megenta
          if [ "x$content" == "x" ] ; then
             content="" ; color=grey
          fi
          if [ "x$site" == "x$MYSITE" -a "$site_cell" != "$MYSITE" ] ; then
             if [ "x$content" == "x" ] ; then
                echo ; echo ; echo
                #echo DEBUG site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck empty content expected NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA
                echo "${check}" | grep -q Throughput+Alternate+MA
                if [ $? -eq 0 ] ; then
                   #echo DEBUG A site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck empty content expected TPUT Alternate NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA"(+1)"
                   NOTOKTPUTA=$(expr $NOTOKTPUTA + 1)
                   #echo DEBUG A site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck empty content expected TPUT Alternate NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA
                else
                   echo "${check}" | grep -q Loss
                   if [ $? -eq 0 ] ; then
                     #echo DEBUG site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck empty content expected Loss NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA
                     NOTOKLOSS=$(expr $NOTOKLOSS + 1)
                   else
                     #echo DEBUG B site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck empty content expected Throughput NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT"(+1)" NOTOKTPUTA=$NOTOKTPUTA
                     NOTOKTPUT=$(expr $NOTOKTPUT + 1)
                     #echo DEBUG B site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck empty content expected Throughput NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPU NOTOKTPUTA=$NOTOKTPUTA
                   fi
                fi
             fi
          elif [ "x$site" != "x$MYSITE" -a "$site_cell" == "$MYSITE" ] ; then
             if [ "x$content" == "x" ] ; then
                echo ; echo ; echo
                #echo DEBUG site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck empty content expected NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA
                echo "${check}" | grep -q Throughput+Alternate+MA
                if [ $? -eq 0 ] ; then
                   #echo DEBUG A site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck empty content expected TPUT Alternate NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA"(+1)"
                   CNOTOKTPUTA=$(expr $CNOTOKTPUTA + 1)
                   #echo DEBUG A site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck empty content expected TPUT Alternate NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA
                else
                   echo "${check}" | grep -q Loss
                   if [ $? -eq 0 ] ; then
                     #echo DEBUG site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck empty content expected Loss NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA
                     CNOTOKLOSS=$(expr $CNOTOKLOSS + 1)
                   else
                     #echo DEBUG B site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck empty content expected Throughput NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT"(+1)" NOTOKTPUTA=$NOTOKTPUTA
                     CNOTOKTPUT=$(expr $CNOTOKTPUT + 1)
                     #echo DEBUG B site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck empty content expected Throughput NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPU NOTOKTPUTA=$NOTOKTPUTA
                   fi
                fi
             fi
          fi
          
          echo "$content" | grep -q %
          if [ $? -eq 0 ] ; then
             [ $(echo $content | sed "s#%##g" | cut -d. -f1) -gt 5 ] && color=red # if packet Loss is more than 5%, it's bad
             contentmilli=$(echo $(echo $content | sed "s#%##") )
             contentmilli=$(echo "scale=2 ; $contentmilli * 1000 " | bc | cut -d. -f1)
             [ "x$contentmilli" == "x" ] && contentmilli=0
             if [ $contentmilli -lt 10000 ] ; then
                content=${contentmilli}"m%"
             fi
             if [ "x$site" == "x$MYSITE" -a "$site_cell" != "$MYSITE" ] ; then               
                #echo DEBUG site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content contentmilli=$contentmilli check=$check ck=$ck Latency expected NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA
                if [ $contentmilli -gt 9000 ] ; then
                   NOTOKLOSS=$(expr $NOTOKLOSS + 1)
                fi
             elif [ "x$site" != "x$MYSITE" -a "$site_cell" == "$MYSITE" ] ; then               
                #echo DEBUG site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content contentmilli=$contentmilli check=$check ck=$ck Latency expected NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA
                if [ $contentmilli -gt 9000 ] ; then
                   CNOTOKLOSS=$(expr $CNOTOKLOSS + 1)
                fi
             fi
          else
             if [ "x$site" == "x$MYSITE" -a "$site_cell" != "$MYSITE" ] ; then
              if [ "x$content" != "x" ] ; then # else
                echo "${check}" | grep -q Throughput+Alternate+MA
                if [ $? -eq 0 ] ; then
                   #echo DEBUG C site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck Throughput+Alternate+MA expected NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA"1?1"
                   #echo DEBUG Alternate check=$check and content=$content 
                   if [ $(echo "scale=2 ; $(echo $content | sed 's#G##g') * 10" | bc | cut -d. -f1) -lt 1 ] ; then # less then 0.1G
                      NOTOKTPUTA=$(expr $NOTOKTPUTA + 1)
                   fi
                   #echo DEBUG C site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck Throughput+Alternate+MA expected NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA"?"
                else
                   #echo DEBUG D site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck Throughput expected NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT"1?1" NOTOKTPUTA=$NOTOKTPUTA
                   tputgb=$(echo $content | sed 's#G##g')
                   [ $(echo "scale=2 ; $(echo $content | sed 's#G##g') * 10" | bc | cut -d. -f1) -lt 1 ] && NOTOKTPUT=$(expr $NOTOKTPUT + 1)
                   #echo DEBUG check=$check and content=$content
                   #echo DEBUG D site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck Throughput expected NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT"?" NOTOKTPUTA=$NOTOKTPUTA
                fi
              fi
             elif [ "x$site" != "x$MYSITE" -a "$site_cell" == "$MYSITE" ] ; then
              if [ "x$content" != "x" ] ; then # else
                echo "${check}" | grep -q Throughput+Alternate+MA
                if [ $? -eq 0 ] ; then
                   #echo DEBUG C site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck Throughput+Alternate+MA expected NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA"1?1"
                   #echo DEBUG Alternate check=$check and content=$content 
                   if [ $(echo "scale=2 ; $(echo $content | sed 's#G##g') * 10" | bc | cut -d. -f1) -lt 1 ] ; then # less then 0.1G
                      CNOTOKTPUTA=$(expr $CNOTOKTPUTA + 1)
                   fi
                   #echo DEBUG C site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck Throughput+Alternate+MA expected NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA"?"
                else
                   #echo DEBUG D site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck Throughput expected NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT"1?1" NOTOKTPUTA=$NOTOKTPUTA
                   tputgb=$(echo $content | sed 's#G##g')
                   [ $(echo "scale=2 ; $(echo $content | sed 's#G##g') * 10" | bc | cut -d. -f1) -lt 1 ] && CNOTOKTPUT=$(expr $CNOTOKTPUT + 1)
                   #echo DEBUG check=$check and content=$content
                   #echo DEBUG D site=MYSITE $site == $MYSITE cell_site=$site_cell content=$content check=$check ck=$ck Throughput expected NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT"?" NOTOKTPUTA=$NOTOKTPUTA
                fi
              fi
             fi
          fi
          #echo "$content" | grep -v "m%"
          #echo DEBUG "[$irow] [$if]" f=$f "shost=$shost cell=$cell" 
          content="<FONT color='black'><a href='$dashboard_gui/maddash/grids/${g}/${shost}/${cell}/${check}' target=_blank> $content </a></FONT>"
          #dashboard_gui=http://psmad.grid.iu.edu/maddash-webui/details.cgi?uri=
          [ "x${shost}" == "x${cell}" ] && content="S-S"
          if [ $(echo "$g" | grep -q Bandwidth ; echo $?) -eq 0 ] ; then
            if [ $irow -eq 1 -a $if -eq $ntest ] ; then
                THCON="$THCON  <td bgcolor='$color'>$content</td> </tr><tr><td colspan=$ncol>&nbsp;</td> "
            else
                THCON="$THCON <td bgcolor='$color'>$content</td>"
            fi
          else
            THCON="$THCON <td bgcolor='$color'>$content</td>"
          fi
       
      #done
      done
      done
      #THCON="$THCON</tr>"
      #while read line ; do status=$; done < $workdir/$h.html
#if [ ] ; then
      echo "$g" | grep -q Bandwidth
      if [ $? -eq 0 ] ; then
        thetype=BW
        echo "<tr><td bgcolor='cyan' rowspan=$rowspan> <a href='http://${shost}/toolkit'  target=_blank> ${site}${thetype} </a></td> $THETD  $THCON </tr>" >>  ${webout}.0
      else
        thetype=LT 
        echo "<tr><td bgcolor='cyan'> <a href='http://${shost}/toolkit'  target=_blank> ${site}${thetype} </a></td> $THETD  $THCON </tr>" >>  ${webout}.0
      fi
   done
done
echo "</table>" >> ${webout}.0
echo "</html>" >> ${webout}.0
/bin/cp ${webout}.0 ${webout}

echo NOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA
echo CNOTOKLOSS=$CNOTOKLOSS CNOTOKTPUT=$CNOTOKTPUT CNOTOKTPUTA=$CNOTOKTPUTA
[ $(expr $(date +%H) % 13) -eq 0 ] && printf "http://melrose.ihepa.ufl.edu:8080/T2/ops/USCMS_PerfSonar_Unmeshed.html\n" | mail -s "INFO USCMS PerfSonar Unmeshed" $notifytowhom
nsites=$(sites | wc -w)
for v in $NOTOKLOSS $NOTOKTPUT $NOTOKTPUTA $CNOTOKLOSS $CNOTOKTPUT $CNOTOKTPUTA ; do
  if [ $(expr 3 \* $v) -le $(expr 2 \* $nsites ] ; then # if test fails with more than 2 / 3 of total sites
     printf "$(basename $0) $(/bin/hostname ) Test fails with more than 2 /3 of sites\nNOTOKLOSS=$NOTOKLOSS NOTOKTPUT=$NOTOKTPUT NOTOKTPUTA=$NOTOKTPUTA\nCNOTOKLOSS=$CNOTOKLOSS CNOTOKTPUT=$CNOTOKTPUT CNOTOKTPUTA=$CNOTOKTPUTA\nSee http://melrose.ihepa.ufl.edu:8080/T2/ops/USCMS_PerfSonar_Unmeshed.html\n" | mail -s "ERROR with perfSonar with $MYSITEnar" $notifytowhom
     break
  fi
done

# check_mk example 
# webisoget -cache $CACHE -form "name=hiddenform" -cert $HOME/.cmssoft/myCert.pem -key $HOME/.cmssoft/myCert.key -out perfsonar1.html -url "https://psetf.grid.iu.edu/etf/check_mk/view.py?host=perfsonar1.ihepa.ufl.edu&output_format=csv_export&site=etf&view_name=host"
exit 0