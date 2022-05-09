Notify #kiwix IRC channel with notification from our projects on:
* Sourcefoge
* Github
* Framagit
* Twitter
* Slack
* Mediawiki

```
docker run \
 -e TWITTER_KEY='XfwAGgXlEWeqzqJh4XxIwn'                                                       \
 -e TWITTER_SECRET='VxF0WMVyBxhrhjlWrdOflducQ7Wv5eK8vFYsy6g0W3jwYIW'                           \
 -e TWITTER_TOKEN_KEY='6162886-9Rs8EZ5Pzhfc1KggZBJ1xb1nLgmxjp2JDFH0Fixo'                       \
 -e TWITTER_TOKEN_SECRET='JucQoVOQa9KX2JjLK66z2o7thECqV3GjY1aeMkG1hx'                          \
 -e KIWIX_GITHUB_TOKEN='AA-2Vr6KtbaGeoOWMNCmX3NVoMJMlpks604UUtwA=='                            \
 -e OPENZIM_GITHUB_TOKEN='AA-2VR60TnSvWppnkmVVU7d5J2Qks62_cK8wA=='                             \
 -e SLACK_TOKEN='xoxp-137430566661-136635882032-241611776544-e4a02fe08ad9f04dessss1b294c7fdcb' \
kiwix/watcherbot 
```