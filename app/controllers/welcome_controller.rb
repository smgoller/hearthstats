class WelcomeController < ApplicationController
  def index

    # Global Stats
    @arena_top = Rails.cache.read('wel#arena_top')
    @con_top = Rails.cache.read('wel#con_top')

    # Decklists
    @recentdecks = Rails.cache.fetch('wel#recent_deck') do
      Deck.where(is_public: true).
              joins(:unique_deck).
              last(7)
    end
    @topdecks = Rails.cache.fetch('wel#top_deck') do
      Deck.where(is_public: true).where('decks.created_at >= ?', 1.week.ago).
                group(:unique_deck_id).
                joins(:unique_deck).
                joins(:user).
                where("unique_decks.num_matches >= ?", 30).
                sort_by { |deck| deck.unique_deck.winrate || 0 }.
                last(7).
                reverse
    end

    # Streams
    # @featured_streams = Stream.get_featured_streamers
    @top_streams = get_top_streamers.first(6)

    render layout: false
  end

  def select_klass
    @klass = params[:klass_id]
    respond_to do |format|
      format.js
    end
  end

  def newsletter_sub
    begin
      c = Cindy.new "http://sendy.hearthstats.net", "cGF9DlbzfS0jBooMv5N3"
      c.subscribe "6V763uDbDJuEja62CUwTlthQ", params[:email]
    rescue Cindy::AlreadySubscribed => e
    end

    respond_to do |format|
      format.html { redirect_to root_path, notice: "Newsletter Subscribed" }
    end
  end

  def demo_user
    sign_in(:user, create_guest_user)
    respond_to do |format|
      format.html { redirect_to root_path }
      format.json { head :no_content }
    end
  end

  def get_ranked_graph_data(season)
    ranked_wr_count = Match.get_klass_ranked_wr(season.begin, season.end)
    @ranked_winrates = ranked_wr_count[0]
    gon.counts = ranked_wr_count[1]
  end

  def liquid_data
    unless current_user_allow?([:plat, :admin])
      redirect_to root_path and return
    end
    klass_ranked_wr = Match.get_klass_ranked_wr(2.weeks.ago, 
                                                DateTime.now)
    render json: klass_ranked_wr
  end

  def generate_report
    # if !current_user.is_admin?
    #   redirect_to root_path, alert: "y u no admin" and return
    # end
    season = 10

    ranked_wr_count = Match.get_klass_ranked_wr(2.weeks.ago, 
                                                DateTime.now)
    @ranked_winrates = ranked_wr_count[0]
    gon.counts = ranked_wr_count[1]

    @prev_global = [
      {"Warlock" => 44.22, "Druid" => 49.73, "Shaman" => 51.56, "Rogue" => 53.60, "Warrior" => 45.60, "Paladin" => 51.79, "Mage" => 53.06, "Hunter" => 44.45, "Priest" => 42.52},
      {"Warlock" => 52.56, "Druid" => 50.97, "Shaman" => 51.15, "Rogue" => 49.41, "Warrior" => 50.92, "Paladin" => 48.42, "Mage" => 47.54, "Hunter" => 48.57, "Priest" => 44.80}]

    matches = Match.where("created_at > ?", 2.weeks.ago)
    # Determine match Class Win Rates
    @classes_array = Klass.list
    classes = Klass.list
    @classarenarate = Hash.new
    @arenatot = Hash.new
    mode_matches = matches.where(mode_id: 1)
    classes.each do |c|
      totalwins = 0
      totalgames = 0
      totalwins = mode_matches.where(klass_id: klasses_hash[c], result_id: 1).count + mode_matches.where(oppclass_id: klasses_hash[c], result_id: 2).count
      totalgames = mode_matches.where(klass_id: klasses_hash[c]).count + mode_matches.where(oppclass_id: klasses_hash[c]).count
      if totalgames == 0
        @classarenarate[c] = 0
      else
        @classarenarate[c] = (totalwins.to_f / totalgames)
      end
      @arenatot[c] = totalgames

    end
    @classarenarate = @classarenarate.sort_by { |name, winsrate| winsrate }.reverse

    # Determine mode_matches Class Win Rates

    @classconrate = Hash.new
    @contot = Hash.new
    mode_matches = matches.where(mode_id: 3)
    classes.each do |c|
      totalwins = 0
      totalgames = 0
      totalwins = mode_matches.where(result_id: 1, klass_id: klasses_hash[c]).count
      totalwins = totalwins + mode_matches.where(oppclass_id: klasses_hash[c], result_id: 2).count
      totalgames = mode_matches.where(klass_id: klasses_hash[c]).count + mode_matches.where(oppclass_id: klasses_hash[c]).count
      if totalgames == 0
        @classconrate[c] = 0
      else
        @classconrate[c] = (totalwins.to_f / totalgames)
      end

      @contot[c] = totalgames
    end
    @classconrate = @classconrate.sort_by { |name, winsrate| winsrate }.reverse

    # Most Played

    @conclassnum = Hash.new
    classes.each do |a|
      @conclassnum[a] = @arenatot[a] + @contot[a]
    end

    # Determine mode_matches Class Win Rates
    # classcombos = classes.combination(2).to_a
    classcombos = Array.new
    classes.each do |c|
      classes.each do |c2|
        classcombos << [c,c2]
      end
    end
    @userarenarate = Array.new
    @totarenagames = Hash.new
    mode_matches = matches.where(mode_id: 1)
    classcombos.each_with_index do |combo, i |
      totalwins = 0
      totalgames = 0
      totalwins = mode_matches.where(klass_id: klasses_hash[combo[0]], oppclass_id: klasses_hash[combo[1]], result_id: 1).count + mode_matches.where(klass_id: klasses_hash[combo[1]], oppclass_id: klasses_hash[combo[0]], result_id: 2).count
      totalgames = mode_matches.where(klass_id: klasses_hash[combo[0]], oppclass_id: klasses_hash[combo[1]],result_id: [1,2]).count + mode_matches.where(klass_id: klasses_hash[combo[1]], oppclass_id: klasses_hash[combo[0]],result_id: [1,2]).count
      @userarenarate << [ combo[0], [combo[1], (totalwins.to_f / totalgames)]]
    end
    # Determine mode_matches Class Win Rates
    @conrate = Array.new
    @totcongames = Hash.new
    mode_matches = matches.where(mode_id: 3)
    classcombos.each_with_index do |combo, i |
      totalwins = 0
      totalgames = 0

      totalwins = mode_matches.where(oppclass_id: klasses_hash[combo[1]], result_id: 1, klass_id: klasses_hash[combo[0]]).count
      totalwins = totalwins + mode_matches.where(oppclass_id: klasses_hash[combo[0]], result_id: 2, klass_id: klasses_hash[combo[1]]).count

      totalgames = mode_matches.where(oppclass_id: klasses_hash[combo[0]], klass_id: klasses_hash[combo[1]], result_id: [1,2]).count + mode_matches.where(oppclass_id: klasses_hash[combo[1]], klass_id: klasses_hash[combo[0]], result_id: [1,2]).count

      @conrate << [ combo[0], [combo[1], (totalwins.to_f / totalgames)]]
    end

    # mode_matches Runs Data
    @arena_runs = Array.new
    classes.each_with_index do |c,i|
      run_count = Array.new(13,0)
      tot_games = ArenaRun.where(klass_id: i+1).count
      ArenaRun.where(klass_id: i+1).includes(:matches).each do |ar|
        run_count[ar.matches.where(result_id: 1).count] += 1 unless ar.matches.where(result_id: 1).count > 12
      end
      run_percent = run_count.map { |e| e.to_f / tot_games }
      @arena_runs << [c, run_count, run_percent]
    end
    html = render_to_string(layout: 'fullpage')
    File.open("#{Rails.root}/public/reports/#{Time.now.strftime('%d_%m_%Y')}.html", 'w') {|f| f.write(html) }
    render layout: 'fullpage'
  end

  def decreport
    render layout: 'fullpage'
  end

  def april_report
    render file: "#{Rails.root}/public/reports/april_report.html", layout: 'fullpage'
  end

  def may_report
    render file: "#{Rails.root}/public/reports/may_report.html", layout: 'fullpage'
  end

  def june_report
    render file: "#{Rails.root}/public/reports/june_report.html", layout: 'fullpage'
  end

  def july_report
    render file: "#{Rails.root}/public/reports/july_report.html", layout: 'fullpage'
  end

  def aug_report
    render file: "#{Rails.root}/public/reports/aug_report.html", layout: 'fullpage'
  end

  def sept_report
    render file: "#{Rails.root}/public/reports/sept_report.html", layout: 'fullpage'
  end

  def novreport
    render layout: 'fullpage'
  end

  private

    def cularenagames(race, days1)
      wins = Array.new(days1, 0)
      wins[0] = 0
      (1..days1).each do |i|
        wins[i] = mode_matches.where(klass: race, result_id: 1).where(created_at: i.days.ago.beginning_of_day..i.days.ago.end_of_day).count
      end
      return wins
    end

    def culcongames(race, days1)
      wins = Array.new(days1, 0)
      wins[0] = 0
      (1..days1).each do |i|
        wins[i] = mode_matches.joins(:deck).where(:result_id => 1, 'decks.race' => race).where(created_at: i.days.ago.beginning_of_day..i.days.ago.end_of_day).count
      end
      return wins
    end

    def create_guest_user
      u = User.create(email: "guest_#{Time.now.to_i}#{rand(999)}@example.com", password: "demouser", guest: true)
      u.save!(validate: false)
      session[:guest_user_id] = u.id

      u
    end

    def get_top_streamers
      begin
        top_streams = Rails.cache.fetch("top_streams", expires_in: 30.minutes) do
          HTTParty.get('https://api.twitch.tv/kraken/search/streams?limit=50&q=hearthstone&client_id=5p5btpott5bcxwgk46azv8tkq49ccrv')['streams']
        end
      rescue
        top_streams = []
      end

      top_streams
    end

end
