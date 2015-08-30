--- 
layout: post
title: "My First Post"
comments: true
tags: [ pretzel, blog ]
---

Several years ago now Scott Hanselman wrote an blog post titled [Your Blog is the Engine of Community](http://www.hanselman.com/blog/YourBlogIsTheEngineOfCommunity.aspx). The basic premise of it, for those too lazy to read it,
was that you should own your own content. Sites like Twitter and Facebook are intrinsically transient and, perhaps more importantly, owned by someone else. "That makes sense!" I thought. And so I had a look about on the internet
came across [Github Pages](https://pages.github.com/) had a quick play and... forgot about it. And then today a friend of mine was looking at ditching Wordpress for their own blog and asked if I had any suggestions. I gave a half
hearted reply about something like [Github Pages](https://pages.github.com/) and then... thought about it... and thought I should finally get my act together and finish playing with them myself.

My initial issue last time I looked into Github Pages was that they run [Jekyll](http://jekyllrb.com/). Which isn't a bad thing, it's a nice big of software, but as a Windows developer it seemed like a bunch of things I've only
had passing exposure to. I had a look for other static blog engines and came across [Pretzel](http://code52.org/pretzel.html). Like Jekyll Pretzel generates a static blog for you from [Markdown](http://daringfireball.net/projects/markdown/)
however unlike Jekyll it's written in .Net and feels more "natural" to a C# developer like myself. I did, however, have a few minor issues along the way, so I figured I'd kill two birds with one stone and write about them.

## 1.  Getting Pretzel

Probably the easiest way to grab Pretzel is actually from [Chocolatey](http://chocolatey.org). It's listed as [Pretzel](https://chocolatey.org/packages/pretzel)

This'd be as simple as;

```dos
choco install pretzel
```

Personally I grabbed the source code from their [Github Page](https://github.com/Code52/pretzel) and built it myself

```dos
git clone https://github.com/Code52/pretzel
cd pretzel
build.cmd
```

After a while you'll end up with `artifacts\Pretzel.exe` which you'll want to add to your path
    
## 2.  Setting up your Github Page

Github actually has really good documentation on this. The basic premise is you set up a new repository wih the name `$YourUsername$.github.io`. Mine, for instance, is [mrmdavidson.github.io](https://github.com/MrMDavidson/mrmdavidson.github.io)

You'll want to clone this locally, add some content, and push it...

```dos
git clone https://github.com/MrMDavidson/mrmdavidson.github.io
cd mrmdavidson.github.io
echo "Hello World!" >> index.md
git add index.md
git commit -am "My first page!"
git push
````

If you then visit your own `$YourUsername$.github.io` you'll see your "Hello World" page. Hooray!
    
## 3.  Now let's make use of Pretzel

To get started with Pretzel is actually pretty straight forward. We're going to jump into the directory we created early and, with Pretzel in our path, tell it to do some things

```dos
cd mrmdavidson.github.io
pretzel.exe create
``` 

This will create all the infrastructure required for your blog and create a sample post and an [about](/about.html) page. But it's all in MarkDown. How do we use it?

Pretzel has two main modes "Taste" and "Bake" (Because Pretzels, get it?). Taste allows you to fire everything up locally and test it. Pretzel includes everything needed for this (including an [Owin](http://owin.org/) based webserver).

```dos
pretzel.exe taste -p 8081
```

![Pretzel Tasting](/img/posts/2015-08-30-myfirstpost/pretzel-tasting.png "Pretzel Tasting")

*(You may need to play around with the `-p 8081` argument to specify a port that's currently not in use on your machine)* 

This will also fire up your default browser and show you your newly created blog post. You can play around with the content by editing the file it created in the `_posts/` directory.

Once you get bored of poking at it we'll commit it and push it to your repository so it can be seen by the world!

```dos
git add *
git commit -am "My new blog!"
git push
```

Now visit your own Github Page. Eg. [mrmdavidson.github.io](http://mrmdavidson.github.io)
    
## 4.  ... But something isn't right!

For me, at least, I noticed some inconsistencies between what Jekyll generated and what Pretzel generated. This seems like something that'd be horrible to debug. So I poked around a little and found that you can use Github PAges
as a completely static host. You don't have to have it generate anything with Jekyll. "Interesting", I thought. How does this work?

Well, remember earlier how I said Pretzel has two modes? Tasting and Baking? We want the baking mode;

```dos
cd mrmdavidson.github.io
pretzel.exe bake
```

![Pretzel Tasting](/img/posts/2015-08-30-myfirstpost/pretzel-tasting.png "Pretzel Tasting")

*Milliseconds later it'll have finished its work.*

Now inside your repository you'll have an `_site` directory. This is a static build of your site (Note: Anything starting with `_` is ignored by Jekyll and Pretzel by convention). You can point your browser here and everything 
should work. But if you push this to your repository it won't have the desired results. What we're going to do is place a ".nojekyll" file in our directory - this is an instruction to Github to not run Jekyll on this repository.
I know this seems counter intuitive, but trust me.

```dos
echo "" > .nojekyll
git add .nojekyll
git commit -am "Opt out of Jekyll generation"
git push
```

Now if you visit your lovely blog... it'll be completely broken. How is this helpful? Stay with me here!

What we're going to do is create a new branch. [Master](https://github.com/MrMDavidson/mrmdavidson.github.io/tree/master) will be used for the generated content of the site. And our new branch, say, [Pretzel](https://github.com/MrMDavidson/mrmdavidson.github.io/tree/pretzel)
will be used to store our working blog. This way both our blog "data" and our generated site is under source control.

To avoid confusion we'll create two new copies of the repository...

```dos
git clone https://github.com/MrMDavidson/mrmdavidson.github.io mrmdavidson.github.io-blog
git clone https://github.com/MrMDavidson/mrmdavidson.github.io mrmdavidson.github.io-generated
cd mrmdavidson.github.io-blog
git checkout -B pretzel
git push origin
```

Now what we'll do is create blog posts in the `mrmdavidson.github.io-blog` directory which pushes to a "Pretzel" branch. Once we've finished tasting these we can generate the static content into master.
Let's start by cleaning master. You'll want to delete from git everything in here but your `.nojekyll` file. Once you've done that...

```dos
cd mrmdavidson.github.io-blog
pretzel.exe bake --destination ..\mrmdavidson.github.io-generated\
```

The `--destination` switch tells Pretzel to generate to a specific, relative-to-current, directory. In this example we're going to generate to our working copy of the Master branch.

We can now add everything in here and push to master...

```dos
cd mrmdavidson.github.io-generated
git add *
git commit -am "Initial generated version of the blog!"
git push origin
```

## 5. Automating it...

That all seems a bit tedious, but repeatable, so what I did was create a [generate.bat](https://github.com/MrMDavidson/mrmdavidson.github.io/blob/4a609925cfaf57f94a48322c3cc1f7af4acb77bc/generate.bat) in my Pretzel branch that bakes the blog, adds everything to git, and pushes it to master...

```dos
pretzel bake --destination ..\mrmdavidson.github.io-generated\
pushd ..\mrmdavidson.github.io-generated
git add *
git commit -am "Generated site"
git push origin
popd
```

This way once I'm finished tasting my blog locally I can just run `generate.bat` and seconds later everything is available to the public!