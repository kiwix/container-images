#!/bin/bash

TEMPLATE="[{\"nickname\":\"slack\",\"server\":\"irc.freenode.org\",\"token\":\"${SLACK_TOKEN}\",\"channelMapping\":{\"#general\":\"#kiwix\"}}]"
echo $TEMPLATE > slack-irc.config.json
slack-irc                                                                  \
    --config="slack-irc.config.json"                                       &

./watcherbot.js                                                            \
    --twitterKey="${TWITTER_KEY}"                                          \
    --twitterSecret="${TWITTER_SECRET}"                                    \
    --twitterTokenKey="${TWITTER_TOKEN_KEY}"                               \
    --twitterTokenSecret="${TWITTER_TOKEN_SECRET}"                         \
    --kiwixGithubToken="${KIWIX_GITHUB_TOKEN}"                             \
    --openzimGithubToken="${OPENZIM_GITHUB_TOKEN}"    

