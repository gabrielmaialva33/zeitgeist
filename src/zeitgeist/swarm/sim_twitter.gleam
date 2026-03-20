import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

pub type Tweet {
  Tweet(author: String, content: String, tick: Int, likes: Int, retweets: Int)
}

pub type TwitterMsg {
  PostTweet(tweet: Tweet)
  LikeTweet(index: Int)
  RetweetTweet(index: Int)
  GetTimeline(limit: Int, reply_to: Subject(List(Tweet)))
  TweetCount(reply_to: Subject(Int))
  TwitterStop
}

type TwitterState {
  TwitterState(world_id: String, tweets: List(Tweet))
}

pub fn start(
  world_id: String,
) -> Result(Subject(TwitterMsg), actor.StartError) {
  let init_state = TwitterState(world_id: world_id, tweets: [])
  let r =
    actor.new(init_state)
    |> actor.on_message(handle_message)
    |> actor.start
  case r {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn post_tweet(tw: Subject(TwitterMsg), tweet: Tweet) -> Nil {
  process.send(tw, PostTweet(tweet))
}

pub fn like_tweet(tw: Subject(TwitterMsg), index: Int) -> Nil {
  process.send(tw, LikeTweet(index))
}

pub fn retweet_tweet(tw: Subject(TwitterMsg), index: Int) -> Nil {
  process.send(tw, RetweetTweet(index))
}

pub fn get_timeline(tw: Subject(TwitterMsg), limit: Int) -> List(Tweet) {
  process.call(tw, waiting: 5000, sending: fn(reply_to) {
    GetTimeline(limit, reply_to)
  })
}

pub fn tweet_count(tw: Subject(TwitterMsg)) -> Int {
  process.call(tw, waiting: 5000, sending: fn(reply_to) { TweetCount(reply_to) })
}

pub fn stop(tw: Subject(TwitterMsg)) -> Nil {
  process.send(tw, TwitterStop)
}

fn handle_message(
  state: TwitterState,
  msg: TwitterMsg,
) -> actor.Next(TwitterState, TwitterMsg) {
  case msg {
    PostTweet(tweet) -> {
      let new_tweets = [tweet, ..state.tweets]
      actor.continue(TwitterState(..state, tweets: new_tweets))
    }

    LikeTweet(idx) -> {
      let updated =
        list.index_map(state.tweets, fn(t, i) {
          case i == idx {
            True -> Tweet(..t, likes: t.likes + 1)
            False -> t
          }
        })
      actor.continue(TwitterState(..state, tweets: updated))
    }

    RetweetTweet(idx) -> {
      let updated =
        list.index_map(state.tweets, fn(t, i) {
          case i == idx {
            True -> Tweet(..t, retweets: t.retweets + 1)
            False -> t
          }
        })
      actor.continue(TwitterState(..state, tweets: updated))
    }

    GetTimeline(limit, reply_to) -> {
      let result = list.take(state.tweets, limit)
      process.send(reply_to, result)
      actor.continue(state)
    }

    TweetCount(reply_to) -> {
      process.send(reply_to, list.length(state.tweets))
      actor.continue(state)
    }

    TwitterStop -> actor.stop()
  }
}
